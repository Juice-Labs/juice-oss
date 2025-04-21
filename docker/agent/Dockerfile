ARG BASE_CONTAINER=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu22.04
ARG VIDEOSDK_VERSION=12.0.16
ARG VK_API_VERSION=1.2.203

# This video sdk container has the video codec sdk stored at /
# The zip file requires a license agreement to be accepted for download
# Retrieved from https://developer.nvidia.com/nvidia-video-codec-sdk
FROM 597595123756.dkr.ecr.us-east-2.amazonaws.com/juicelabs/nvidia/video-codec:${VIDEOSDK_VERSION} AS video-codec

FROM ${BASE_CONTAINER} AS build
ARG VK_API_VERSION
ARG VIDEOSDK_VERSION
RUN apt-get update && \
    apt-get install -y unzip
# Largely pulled from https://gitlab.com/nvidia/container-images/video-codec-sdk/-/blob/master/ubuntu18.04/Dockerfile
COPY --from=video-codec /Video_Codec_SDK_${VIDEOSDK_VERSION}.zip /Video_Codec_SDK_${VIDEOSDK_VERSION}.zip
RUN CUDA_VERSION=$(realpath /usr/local/cuda | cut -d "-" -f2) && \
    CPU_ARCH=$(uname -p) && \
    mkdir -p /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/include && \
    mkdir -p /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs && \
    unzip -j Video_Codec_SDK_${VIDEOSDK_VERSION}.zip \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Interface/cuviddec.h \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Interface/nvcuvid.h \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Interface/nvEncodeAPI.h \
          -d /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/include && \
    unzip -j Video_Codec_SDK_${VIDEOSDK_VERSION}.zip \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Lib/linux/stubs/${CPU_ARCH}/libnvcuvid.so \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Lib/linux/stubs/${CPU_ARCH}/libnvidia-encode.so \
          -d /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs && \
# This needs to be fixed. Shouldn't be linking to libnvidia-encode.so.1
    mv /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs/libnvidia-encode.so /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs/libnvidia-encode.so.1 && \
    ln -s -T libnvidia-encode.so.1 /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs/libnvidia-encode.so

COPY root/ /build
RUN sed -e "s/<<VK_API_VERSION>>/${VK_API_VERSION}/" /build/usr/share/vulkan/icd.d/nvidia_icd.json && \
    chmod 755 /build/home/juice/start-agent.sh && \
    chown 1000:1000 /build/home/juice/start-agent.sh

FROM ${BASE_CONTAINER}
ARG VK_API_VERSION
ARG JUICE_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV JUICE_VERSION=${JUICE_VERSION}
ENV JUICE_HOST_PORT=7865
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64:/usr/local/cuda/lib64/stubs:/root
ENV FONTCONFIG_PATH=/etc/fonts
ENV NVIDIA_DISABLE_REQUIRE=1
ENV NVIDIA_DRIVER_CAPABILITIES=compute,graphics,utility,video

# Run all the apt commands in one layer
RUN apt-get update && \
    apt-get install -y software-properties-common pciutils && \
# Install libstdc++-10
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get install -y libstdc++-10-dev && \
# Install opengl support
    apt-get install -y libglvnd0 libgl1 libegl1 && \
# Install vulkan support
    apt-get install -y libvulkan1 && \
# For msquic
    apt-get install -y libnuma1 && \
    rm -rf /var/lib/apt/lists/* && \
# Add juice user
    useradd -u 1000 -ms /bin/bash juice


# Copy all the built data into one layer
COPY --from=build /build .

# Finally, Juice installation
ADD juice-gpu-linux.tar.gz /home/juice/

USER juice
WORKDIR /home/juice/
CMD ["./start-agent.sh"]

LABEL "maintainer"="JUICE TECHNOLOGIES <juicelabs.co>"
LABEL "juicelabs.co/vulkan/api_version"=${VK_API_VERSION}
LABEL "juicelabs.co/version"=${JUICE_VERSION}