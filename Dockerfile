# daemon runs in the background
# run something like tail /var/log/batamcoind/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/batamcoind:/var/lib/batamcoind -v $(pwd)/wallet:/home/batamcoin --rm -ti batamcoin:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG BATAMCOIN_BRANCH=master
ENV BATAMCOIN_BRANCH=${BATAMCOIN_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/batamcoin/batamcoin.git /src/batamcoin && \
    cd /src/batamcoin && \
    git checkout $BATAMCOIN_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/BatamCoind /usr/local/bin/BatamCoind && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/BatamCoind && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/batamcoin && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev librocksdb-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the batamcoind service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/batamcoind batamcoind && \
    useradd -s /bin/bash -m -d /home/batamcoin batamcoin && \
    mkdir -p /etc/services.d/batamcoind/log && \
    mkdir -p /var/log/batamcoind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/batamcoind/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/batamcoind/run && \
    echo "cd /var/lib/batamcoind" >> /etc/services.d/batamcoind/run && \
    echo "export HOME /var/lib/batamcoind" >> /etc/services.d/batamcoind/run && \
    echo "s6-setuidgid batamcoind /usr/local/bin/BatamCoind" >> /etc/services.d/batamcoind/run && \
    chmod +x /etc/services.d/batamcoind/run && \
    chown nobody:nogroup /var/log/batamcoind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/batamcoind/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/batamcoind/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/batamcoind" >> /etc/services.d/batamcoind/log/run && \
    chmod +x /etc/services.d/batamcoind/log/run && \
    echo "/var/lib/batamcoind true batamcoind 0644 0755" > /etc/fix-attrs.d/batamcoind-home && \
    echo "/home/batamcoin true batamcoin 0644 0755" > /etc/fix-attrs.d/batamcoin-home && \
    echo "/var/log/batamcoind true nobody 0644 0755" > /etc/fix-attrs.d/batamcoind-logs

VOLUME ["/var/lib/batamcoind", "/home/batamcoin","/var/log/batamcoind"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/batamcoin export HOME /home/batamcoin s6-setuidgid batamcoin /bin/bash"]
