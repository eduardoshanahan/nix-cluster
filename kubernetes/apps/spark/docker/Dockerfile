# Custom Spark image with S3 support for homelab
FROM apache/spark:3.5.3

USER root

# Download hadoop-aws and AWS SDK JARs for S3 access
# Versions must match Hadoop version in Spark (3.3.4 for Spark 3.5.3)
RUN curl -fsSL -o ${SPARK_HOME}/jars/hadoop-aws-3.3.4.jar \
    https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    curl -fsSL -o ${SPARK_HOME}/jars/aws-java-sdk-bundle-1.12.262.jar \
    https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    chmod 644 ${SPARK_HOME}/jars/hadoop-aws-3.3.4.jar ${SPARK_HOME}/jars/aws-java-sdk-bundle-1.12.262.jar

# Verify JARs were downloaded
RUN ls -lh ${SPARK_HOME}/jars/hadoop-aws-3.3.4.jar ${SPARK_HOME}/jars/aws-java-sdk-bundle-1.12.262.jar

USER 185

# Metadata
LABEL org.opencontainers.image.title="Apache Spark with S3 support"
LABEL org.opencontainers.image.description="Apache Spark 3.5.3 with hadoop-aws JARs for MinIO/S3 event logging"
LABEL org.opencontainers.image.version="3.5.3-s3"
LABEL org.opencontainers.image.source="https://gitea.hhlab.home.arpa/hhlab-infrastructure/nix-cluster"
