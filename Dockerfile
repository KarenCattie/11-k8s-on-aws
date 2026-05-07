# ----- Stage 1: build the JAR using Gradle -----
# Uses an image that already has Java 17 + Gradle, so Jenkins doesn't need them.
FROM gradle:8.5-jdk17 AS build
WORKDIR /app

# Copy build files first for better Docker layer caching
COPY build.gradle settings.gradle ./
COPY src ./src

# Run gradle build INCLUDING tests. If tests fail, docker build fails and the Jenkins
# pipeline fails — so this stage doubles as the test gate.
RUN gradle build --no-daemon

# ----- Stage 2: tiny runtime image, just the JAR -----
FROM openjdk:17.0.2-jdk
EXPOSE 8080
WORKDIR /opt/app
COPY --from=build /app/build/libs/bootcamp-kubernetes-exercise-project-1.0-SNAPSHOT.jar app.jar
CMD ["java", "-jar", "app.jar"]
