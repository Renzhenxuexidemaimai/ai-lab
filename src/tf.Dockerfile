# Base image built from `base.Dockerfile`

FROM nvaitc/ai-lab:19.10-base

LABEL maintainer="Timothy Liu <timothyl@nvidia.com>"

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    TF_FORCE_GPU_ALLOW_GROWTH=true

# install our own build of TensorFlow

USER root

ENV TRT_VERSION 6.0.1-1+cuda10.0

RUN apt-get update && \
    apt-get install -yq --no-upgrade \
      libcudnn7-dev=${CUDNN_VERSION}-1+cuda10.0 \
      protobuf-compiler \
      libnvinfer6=${TRT_VERSION} libnvonnxparsers6=${TRT_VERSION} \
      libnvparsers6=${TRT_VERSION} libnvinfer-plugin6=${TRT_VERSION} \
      libnvinfer-dev=${TRT_VERSION} libnvonnxparsers-dev=${TRT_VERSION} \
      libnvparsers-dev=${TRT_VERSION} libnvinfer-plugin-dev=${TRT_VERSION} && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

USER $NB_UID

ENV TENSORFLOW_URL=https://github.com/tlkh/getcuda/releases/download/0d/tensorflow-2.0.0-cp36-cp36m-linux_x86_64.whl \
    TENSORFLOW_FILENAME=tensorflow-2.0.0-cp36-cp36m-linux_x86_64.whl.whl
    
RUN cd $HOME/ && \
    echo -c "Downloading ${TENSORFLOW_FILENAME} from ${TENSORFLOW_URL}" && \
    wget -O ${TENSORFLOW_FILENAME} ${TENSORFLOW_URL} && \
    pip install --no-cache-dir --ignore-installed PyYAML \
      tensorflow_datasets \
      tensorflow-hub \
      tensorflow-probability \
      tensorflow-model-optimization \
      && \
    pip uninstall tensorflow tensorflow-gpu -y && \
    pip install --no-cache-dir ${TENSORFLOW_FILENAME} && \
    rm -rf $HOME/${TENSORFLOW_FILENAME} && \
    jupyter lab clean && \
    conda clean -tipsy && \
    conda build purge-all && \
    find $CONDA_DIR -type f,l -name '*.a' -delete && \
    find $CONDA_DIR -type f,l -name '*.pyc' -delete && \
    find $CONDA_DIR -type f,l -name '*.js.map' -delete && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /tmp/* && \
    rm -rf $HOME/.cache && \
    rm -rf $HOME/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions $HOME

# OpenMPI + Horovod

USER root

ENV HOROVOD_GPU_ALLREDUCE=NCCL \
    HOROVOD_WITH_TENSORFLOW=1

RUN apt-get update && \
    apt-get install -yq --no-upgrade \
      openssh-client \
      openssh-server \
      libopenmpi-dev \
      libomp-dev \
      librdmacm1 \
      libibverbs1 \
      ibverbs-providers && \
    apt-get autoremove -y && \
    apt-get clean && \
    mkdir /tmp/openmpi && \
    cd /tmp/openmpi && \
    wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.1.tar.gz && \
    tar zxf openmpi-4.0.1.tar.gz && \
    cd openmpi-4.0.1 && \
    ./configure --enable-orterun-prefix-by-default && \
    make -j $(nproc) all && \
    make install && \
    ldconfig && \
    ldconfig /usr/local/cuda/targets/x86_64-linux/lib/stubs && \
    cd /tmp/* && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
    rm -rf $HOME/.cache && \
    rm -rf $HOME/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions $HOME

USER root

RUN apt-get update && \
    apt-get install -yq --no-upgrade \
      cuda-nvml-dev-$CUDA_PKG_VERSION \
      cuda-command-line-tools-$CUDA_PKG_VERSION \
      cuda-libraries-dev-$CUDA_PKG_VERSION \
      cuda-minimal-build-$CUDA_PKG_VERSION \
      libnccl-dev=$NCCL_VERSION-1+cuda10.0 && \
    pip install --no-cache-dir horovod && \
    apt-get remove -yq \
      cuda-nvml-dev-$CUDA_PKG_VERSION \
      cuda-command-line-tools-$CUDA_PKG_VERSION \
      cuda-libraries-dev-$CUDA_PKG_VERSION \
      libnccl-dev=$NCCL_VERSION-1+cuda10.0 && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* && \
    rm -rf /tmp/* && \
    rm -rf $HOME/.cache && \
    rm -rf $HOME/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions $HOME

USER root

RUN ldconfig && \
    mv /usr/local/bin/mpirun /usr/local/bin/mpirun.real && \
    echo '#!/bin/bash' > /usr/local/bin/mpirun && \
    echo 'mpirun.real --allow-run-as-root "$@"' >> /usr/local/bin/mpirun && \
    chmod a+x /usr/local/bin/mpirun && \
    echo "hwloc_base_binding_policy = none" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "rmaps_base_mapping_policy = slot" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "btl_tcp_if_exclude = lo,docker0" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo NCCL_DEBUG=INFO >> /etc/nccl.conf && \
    mkdir -p /var/run/sshd && \
    cat /etc/ssh/ssh_config | grep -v StrictHostKeyChecking > /etc/ssh/ssh_config.new && \
    echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config.new && \
    mv /etc/ssh/ssh_config.new /etc/ssh/ssh_config

# Switch back to jovyan to avoid accidental container runs as root

USER $NB_UID
