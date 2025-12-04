# Dockerfile for API Gateway
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copy parent POM
COPY pom.xml .

# Copy api-gateway files
COPY api-gateway/pom.xml api-gateway/
COPY api-gateway/src api-gateway/src

# Create placeholder pom.xml files for other modules to satisfy parent POM
# These need parent reference to work with Maven reactor
RUN mkdir -p common/src/main/java create-service/src/main/java lookup-service/src/main/java stats-service/src/main/java && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">\n  <modelVersion>4.0.0</modelVersion>\n  <parent>\n    <groupId>com.shortify</groupId>\n    <artifactId>shortify-services</artifactId>\n    <version>1.0.0</version>\n  </parent>\n  <artifactId>common</artifactId>\n  <packaging>pom</packaging>\n</project>\n' > common/pom.xml && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">\n  <modelVersion>4.0.0</modelVersion>\n  <parent>\n    <groupId>com.shortify</groupId>\n    <artifactId>shortify-services</artifactId>\n    <version>1.0.0</version>\n  </parent>\n  <artifactId>create-service</artifactId>\n  <packaging>pom</packaging>\n</project>\n' > create-service/pom.xml && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">\n  <modelVersion>4.0.0</modelVersion>\n  <parent>\n    <groupId>com.shortify</groupId>\n    <artifactId>shortify-services</artifactId>\n    <version>1.0.0</version>\n  </parent>\n  <artifactId>lookup-service</artifactId>\n  <packaging>pom</packaging>\n</project>\n' > lookup-service/pom.xml && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">\n  <modelVersion>4.0.0</modelVersion>\n  <parent>\n    <groupId>com.shortify</groupId>\n    <artifactId>shortify-services</artifactId>\n    <version>1.0.0</version>\n  </parent>\n  <artifactId>stats-service</artifactId>\n  <packaging>pom</packaging>\n</project>\n' > stats-service/pom.xml

# Build the project
RUN mvn clean package -DskipTests -pl api-gateway

# Runtime stage
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring
USER spring:spring

# Copy JAR
COPY --from=build /app/api-gateway/target/api-gateway-*.jar app.jar

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]

