FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG ANDROID_CMDLINE_TOOLS=11076708
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=/home/vscode/.local/bin:${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk-headless \
    ca-certificates curl unzip zip python3 python3-pip git \
    libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libxrender1 \
    libgl1 libfontconfig1 libasound2 && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    curl -fsSL -o /tmp/cmdline-tools.zip \
      https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/android-tools && \
    mv /tmp/android-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm -rf /tmp/cmdline-tools.zip /tmp/android-tools && \
    yes | sdkmanager --licenses >/dev/null || true && \
    sdkmanager --sdk_root=${ANDROID_HOME} \
      "platform-tools" \
      "platforms;android-35" \
      "build-tools;35.0.1" \
      "cmdline-tools;latest" \
      "cmake;3.10.2.4988404" \
      "ndk;28.1.13356709"

RUN java -version && sdkmanager --version
