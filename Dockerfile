FROM oraclelinux8_oracle19c

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1521

ENTRYPOINT ["/entrypoint.sh"]