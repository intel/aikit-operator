# Build the manager binary
FROM registry.redhat.io/openshift4/ose-helm-operator:v4.9

### Required OpenShift Labels
LABEL name="Intel\u00ae oneAPI Analytics Toolkit Operator" \
      maintainer="abolfazl.shahbazi@intel.com" \
      vendor="Intel Corporation" \
      version="v2023.1.0" \
      release="2023.1.0" \
      summary="Intel\u00ae oneAPI Analytics Toolkit Operator" \
      description="Intel\u00ae oneAPI Analytics Toolkit Operator"

USER root
RUN yum -y update-minimal --security --sec-severity=Important --sec-severity=Critical && \
    yum -y update cyrus-sasl-lib
USER 1001

ENV HOME=/opt/helm

COPY licenses /licenses
COPY watches.yaml ${HOME}/watches.yaml
COPY helm-charts  ${HOME}/helm-charts

WORKDIR ${HOME}
