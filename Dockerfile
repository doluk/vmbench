FROM ubuntu:latest

RUN DEBIAN_FRONTEND=noninteractive \
        apt-get update && apt-get install -y \
            language-pack-en

ENV LANG=en_US.UTF-8
ENV WORKON_HOME=/usr/local/python-venvs
ENV GOMAXPROCS=1

RUN mkdir -p /usr/local/python-venvs
RUN mkdir -p /usr/go/
ENV GOPATH=/usr/go/



RUN DEBIAN_FRONTEND=noninteractive \
        apt-get update && apt-get install -y \
            autoconf automake libtool build-essential \
             git nodejs golang gosu wget

# Compile python3.13 from source
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
        wget build-essential zlib1g-dev \
        libncurses5-dev libgdbm-dev libnss3-dev libssl-dev \
        libsqlite3-dev libreadline-dev libffi-dev curl \
        libbz2-dev

RUN wget https://www.python.org/ftp/python/3.13.1/Python-3.13.1.tgz -O /tmp/Python-3.13.1.tgz
RUN tar -xzf /tmp/Python-3.13.1.tgz -C /tmp/
RUN cd /tmp/Python-3.13.1 && CFLAGS="-fPIC" ./configure --enable-optimizations && make -j$(nproc) && make altinstall

# Use Update-alternative to point python and pip to the python3.13 version
RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3.13 1 && \
    update-alternatives --set python /usr/local/bin/python3.13 && \
    update-alternatives --install /usr/bin/pip pip /usr/local/bin/pip3.13 1 && \
    update-alternatives --set pip /usr/local/bin/pip3.13 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.13 1 && \
    update-alternatives --set python3 /usr/local/bin/python3.13 && \
    update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip3.13 1 && \
    update-alternatives --set pip3 /usr/local/bin/pip3.13

ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
 

# Download the Zig binary
RUN wget "https://ziglang.org/builds/zig-linux-x86_64-0.14.0-dev.2837+f38d7a92c.tar.xz"

# Extract the tarball
RUN tar -xJf zig-linux-x86_64-0.14.0-dev.2837+f38d7a92c.tar.xz

# Move zig to /usr/local/
RUN mv zig-linux-x86_64-0.14.0-dev.2837+f38d7a92c /usr/local/zig

# Add zig to PATH
ENV PATH=$PATH:/usr/local/zig

# Add zig to PATH
ENV PATH=$PATH:/usr/local/zig

RUN pip3 install setuptools Cython

RUN git clone https://github.com/kython28/leviathan.git && cd leviathan && git checkout develop && git pull origin && python3 setup.py \
    install

RUN pip3 install vex
RUN vex --python=python3 -m bench pip install -U pip
RUN mkdir -p /var/lib/cache/pip

ADD servers /usr/src/servers
RUN cd /usr/src/servers && go mod init myapp && \
    go mod tidy && go build goecho.go &&  go build gohttp.go
RUN vex bench pip --cache-dir=/var/lib/cache/pip \
        install -r /usr/src/servers/requirements.txt

RUN vex bench pip freeze -r /usr/src/servers/requirements.txt

EXPOSE 25000

VOLUME /var/lib/cache
VOLUME /tmp/sockets

ADD entrypoint /entrypoint
RUN chmod +x /entrypoint

ENTRYPOINT ["/bin/bash", "/entrypoint"]


