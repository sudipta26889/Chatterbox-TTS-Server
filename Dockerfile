FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ARG RUNTIME=nvidia

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
# Set the Hugging Face home directory for better model caching
ENV HF_HOME=/app/hf_cache

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1 \
    ffmpeg \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a symlink for python3 to be python for convenience
RUN ln -s /usr/bin/python3 /usr/bin/python

# Set up working directory
WORKDIR /app

# Copy ALL requirements files
COPY requirements.txt .
COPY requirements-nvidia.txt .
COPY requirements-rocm.txt .

# Upgrade pip
RUN pip3 install --no-cache-dir --upgrade pip

# --- CRITICAL FIX: Install PyTorch first, then chatterbox without deps ---
RUN if [ "$RUNTIME" = "nvidia" ]; then \
        echo "Step 1: Installing PyTorch Nightly with sm_120 (Blackwell) support..." && \
        pip3 install --no-cache-dir --index-url https://download.pytorch.org/whl/nightly/cu128 \
            torch torchvision torchaudio && \
        echo "Step 2: Installing chatterbox WITHOUT torch dependency..." && \
        pip3 install --no-cache-dir --no-deps git+https://github.com/devnen/chatterbox.git && \
        echo "Step 3: Installing remaining dependencies..." && \
        pip3 install --no-cache-dir -r requirements-nvidia.txt; \
    elif [ "$RUNTIME" = "rocm" ]; then \
        echo "Installing ROCm PyTorch..." && \
        pip3 install --no-cache-dir -r requirements-rocm.txt; \
    else \
        echo "Installing CPU PyTorch..." && \
        pip3 install --no-cache-dir -r requirements.txt; \
    fi
# --------------------------------------------------

# Copy the rest of the application code
COPY . .

# Create required directories for the application (fixed syntax error)
RUN mkdir -p model_cache reference_audio outputs voices logs hf_cache

# Expose the port the application will run on
EXPOSE 8004

# Command to run the application
CMD ["python3", "server.py"]