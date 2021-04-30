#-----------------------------------------------------------------------------------------
# Copyright (c) Fortinet Corporation. All rights reserved.
# Licensed under the GNU License. See LICENSE in the project root for license information.
#-----------------------------------------------------------------------------------------

FROM python:3.7-stretch
ENV PATH /usr/local/bin:$PATH

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# This Dockerfile adds a non-root 'vscode' user with sudo access. However, for Linux,
# this user's GID/UID must match your local user UID/GID to avoid permission issues
# with bind mounts. Update USER_UID / USER_GID if yours is not 1000. See
# https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Configure apt
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils 2>&1 \
# Install git, process tools, lsb-release (common in install instructions for CLIs)
    && apt-get -y install git procps lsb-release \
# Install any missing dependencies for enhanced language service
    && apt-get install -y libicu[0-9][0-9] \
    # Install pylint
    && pip3 --disable-pip-version-check --no-cache-dir install pylint \
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    # Install and configure openssh-server
    && apt-get install -y openssh-server screen xorriso net-tools \
    && mkdir /var/run/sshd \
    && echo $USERNAME':PASSWORD_FOR_USER_'$USERNAME | chpasswd \
    && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd \
    # Nginx to serve data through http download for testing
    && apt-get install -y nginx \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install pip2 and Python dependencies from requirements.txt if it exists
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
RUN /usr/bin/python get-pip.py

# Install Python packages
RUN pip3 install netaddr pexpect requests netaddr jmespath fortiosapi==0.11.1 jinja2==2.10.1
RUN pip2 install netaddr pexpect requests netaddr jmespath fortiosapi==0.11.1 jinja2==2.10.1

# Install Ansible 2.9
RUN pip3 install ansible==2.9.*

#############################
# Expose SSH port 22
EXPOSE 22
#############################

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=