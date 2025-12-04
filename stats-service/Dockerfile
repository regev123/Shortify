# Dockerfile for Stats Service
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copy parent POM
COPY pom.xml .
COPY common/pom.xml common/
COPY common/src common/src

# Copy stats-service files
COPY stats-service/pom.xml stats-service/
COPY stats-service/src stats-service/src

# Create placeholder pom.xml files for other modules to satisfy parent POM
# These need parent reference to work with Maven reactor
RUN mkdir -p create-service/src/main/java lookup-service/src/main/java api-gateway/src/main/java && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">\n  <modelVersion>4.0.0</modelVersion>\n  <parent>\n    <groupId>com.shortify</groupId>\n    <artifactId>shortify-services</artifactId>\n    <version>1.0.0</version>\n  </parent>\n  <artifactId>create-service</artifactId>\n  <packaging>pom</packaging>\n</project>\n' > create-service/pom.xml && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">\n  <modelVersion>4.0.0</modelVersion>\n  <parent>\n    <groupId>com.shortify</groupId>\n    <artifactId>shortify-services</artifactId>\n    <version>1.0.0</version>\n  </parent>\n  <artifactId>lookup-service</artifactId>\n  <packaging>pom</packaging>\n</project>\n' > lookup-service/pom.xml && \
    printf '<?xml version="1.0" encoding="UTF-8"?>\n<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">\n  <modelVersion>4.0.0</modelVersion>\n  <parent>\n    <groupId>com.shortify</groupId>\n    <artifactId>shortify-services</artifactId>\n    <version>1.0.0</version>\n  </parent>\n  <artifactId>api-gateway</artifactId>\n  <packaging>pom</packaging>\n</project>\n' > api-gateway/pom.xml

# Build the project
RUN mvn clean package -DskipTests -pl stats-service -am

# Runtime stage
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring
USER spring:spring

# Copy JAR
COPY --from=build /app/stats-service/target/stats-service-*.jar app.jar

EXPOSE 8083

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8083/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]

