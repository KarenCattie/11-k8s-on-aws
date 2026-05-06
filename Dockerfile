# ----- Stage 1: build the JAR using Gradle -----
# Uses an image that already has Java 17 + Gradle, so Jenkins doesn't need them.
FROM gradle:8.5-jdk17 AS build
WORKDIR /app

# Copy build files first for better Docker layer caching
COPY build.gradle settings.gradle ./
COPY src ./src

# -x test skips tests during the docker build (Jenkins runs tests in its own stage)
RUN gradle build --no-daemon -x test

# ----- Stage 2: tiny runtime image, just the JAR -----
FROM openjdk:17.0.2-jdk
EXPOSE 8080
WORKDIR /opt/app
COPY --from=build /app/build/libs/bootcamp-kubernetes-exercise-project-1.0-SNAPSHOT.jar app.jar
CMD ["java", "-jar", "app.jar"]
