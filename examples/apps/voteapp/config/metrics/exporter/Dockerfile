FROM openjdk:8
#FROM amazonlinux
WORKDIR /app
COPY target/prom-stats.jar /app/prom-stats.jar
COPY front.out /app/front.out
COPY cron-run.sh /app/cron-run.sh
EXPOSE 9099
#ENTRYPOINT ["java", "-jar", "prom-stats.jar"]
ENTRYPOINT ["./cron-run.sh"]
#CMD ./cron-run.sh
#ENTRYPOINT ["java", "-jar", "prom-stats.jar"]
