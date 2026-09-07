FROM steamcmd/steamcmd:latest

# Install everything the bare image is missing
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    rsync \
    jq \
  && rm -rf /var/lib/apt/lists/*

