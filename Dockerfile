FROM ubuntu:zesty
LABEL description="A daily build of LEDE trunk"


RUN sed -i 's%archive.ubuntu.com%mirror.aarnet.edu.au/pub/ubuntu/archive/ubuntu%' /etc/apt/sources.list
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y -q && \
apt-get install -y -q --force-yes build-essential subversion git-core libncurses5-dev zlib1g-dev gawk flex quilt libssl-dev xsltproc libxml-parser-perl mercurial bzr ecj cvs unzip wget curl intltool

#intltool for modemmanager

#RUN useradd -ms /bin/bash lede

#RUN export uid=1000 gid=1000 && \
#    mkdir -p /home/${user} && \
#    echo "${user}:x:${uid}:${gid}:$user,,,:/home/${user}:/bin/bash" >> /etc/passwd && \
#    echo "${user}:x:${uid}:" >> /etc/group && \
#    mkdir -p /etc/sudoers.d && \
#    echo "${user} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${user} && \
#    chmod 0440 /etc/sudoers.d/${user}

#RUN chown -R ${user}:${user} /home/{user}

#USER lede
ENV TERM xterm

WORKDIR /home/lede

VOLUME /home/lede/data
