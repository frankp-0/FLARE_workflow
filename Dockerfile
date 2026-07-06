FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
  wget \
  default-jre \
  python3 \
  python3-pip \
  && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir \
  numpy \
  scikit-learn

RUN wget https://faculty.washington.edu/browning/flare.jar
RUN wget -O /usr/local/bin/create_model_file.py \
  https://raw.githubusercontent.com/browning-lab/flare/refs/heads/master/create_model_file.py \
  && chmod +x /usr/local/bin/create_model_file.py
