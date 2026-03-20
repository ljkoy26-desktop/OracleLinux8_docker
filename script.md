# Oracle 19c on Oracle Linux 8 Docker - 설치 스크립트

---

## 1. Docker 이미지 다운로드 및 컨테이너 실행

```bash
# Oracle Linux 8 이미지 pull
docker pull oraclelinux:8

# 컨테이너 실행 (포트 1521 매핑, --privileged 필요)
docker run -d \
  --name oraclelinux8_oracle19c \
  --privileged \
  -p 1521:1521 \
  oraclelinux:8 \
  /bin/bash -c "while true; do sleep 1; done"

```

> Oracle RPM 파일을 컨테이너에 복사 (호스트에서 실행)
> ```bash
> docker cp oracle-database-ee-19c-1.0-1.x86_64.rpm oraclelinux8_oracle19c:/tmp/
> ```



# 컨테이너 내부 접속
docker exec -it oraclelinux8_oracle19c bash


---

## 2. 기본 패키지 설치

```bash
# 시스템 업데이트
dnf update -y

# vim 설치
dnf install -y vim

# ifconfig 설치 (net-tools 패키지)
dnf install -y net-tools

# Oracle Database Preinstall RPM 설치
# (커널 파라미터 자동 설정, oracle 유저 자동 생성)
dnf install -y oracle-database-preinstall-19c
```

---

## 3. Oracle Database 19c RPM 설치

```bash
# RPM 로컬 설치 (파일이 /tmp에 복사되어 있다고 가정)
dnf localinstall -y /tmp/oracle-database-ee-19c-1.0-1.x86_64.rpm
```

---

## 4. DB 구성 파일 수정 (SID: orcl, 포트: 1521)

```bash
# 설정 파일 편집
vim /etc/sysconfig/oracledb_ORCLCDB-19c.conf
```

아래와 같이 수정:

```
ORACLE_SID=orcl
ORACLE_PDB=orclpdb
ORACLE_CHARACTERSET=AL32UTF8
LISTENER_PORT=1521
```

---

## 5. 데이터베이스 생성 및 구성

```bash
# 데이터베이스 자동 구성 실행 (10~20분 소요)
/etc/init.d/oracledb_ORCLCDB-19c configure
```

---

## 6. oracle 유저 환경 변수 설정

```bash
cat <<'EOT' >> /home/oracle/.bash_profile

# Oracle Settings
export ORACLE_SID=orcl
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin
EOT

# 즉시 적용
source /home/oracle/.bash_profile
```

---

## 7. 계정 비밀번호 설정 및 scott 계정 생성

```bash
# oracle 유저로 전환
su - oracle

# sqlplus 접속 (sysdba 권한)
sqlplus / as sysdba
```

sqlplus 프롬프트에서 실행:

```sql
-- sys 비밀번호 변경
ALTER USER sys IDENTIFIED BY tiger;

-- system 비밀번호 변경
ALTER USER system IDENTIFIED BY tiger;

-- scott 계정 생성 및 권한 부여
CREATE USER scott IDENTIFIED BY tiger;
GRANT CONNECT, RESOURCE TO scott;
ALTER USER scott QUOTA UNLIMITED ON USERS;

EXIT;
```

---

## 8. 리스너 시작 및 확인

```bash
# oracle 유저로 실행
su - oracle

# 리스너 시작
lsnrctl start

# 리스너 상태 확인 (포트 1521 확인)
lsnrctl status

# 네트워크 포트 확인
netstat -tlnp | grep 1521
```


  # listener.ora 수정
  vim /opt/oracle/product/19c/dbhome_1/network/admin/listener.ora

  파일 내용에서 HOST 부분을 아래처럼 변경:

 LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = oraclelinux8-oracle19c)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )




# tnsnames.ora 수정
vim /opt/oracle/product/19c/dbhome_1/network/admin/tnsnames.ora

LISTENER_ORCL =
  (ADDRESS = (PROTOCOL = TCP)(HOST = oraclelinux8-oracle19c)(PORT = 1521))


ORCL =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oraclelinux8-oracle19c)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = orcl)
    )
  )




  저장 후 리스너 재시작

  lsnrctl start

---

## 9. 접속 테스트

```bash
# sys 접속 테스트
sqlplus sys/tiger@localhost:1521/orcl as sysdba

# system 접속 테스트
sqlplus system/tiger@localhost:1521/orcl

# scott 접속 테스트
sqlplus scott/tiger@localhost:1521/orcl
```

---

## 정보 요약

| 항목 | 값 |
|------|-----|
| SID | orcl |
| 포트 | 1521 |
| sys 비밀번호 | tiger |
| system 비밀번호 | tiger |
| scott 비밀번호 | tiger |
| ORACLE_BASE | /opt/oracle |
| ORACLE_HOME | /opt/oracle/product/19c/dbhome_1 |



---

## 10. 자동 시작 이미지 빌드 (Dockerfile + entrypoint.sh)

> 현재 설치 완료된 컨테이너를 커밋한 뒤, Dockerfile로 자동 시작 이미지를 빌드합니다.

```bash
# 1) 현재 컨테이너를 이미지로 커밋
docker commit oraclelinux8_oracle19c oraclelinux8_oracle19c

# 2) Dockerfile 기반으로 자동 시작 이미지 빌드
#    (Dockerfile, entrypoint.sh 가 같은 디렉토리에 있어야 함)
docker build -t oracle19c:latest .
```

---

## 11. 자동 시작 컨테이너 실행

```bash
# 기존 컨테이너 삭제 (있을 경우)
docker rm -f oraclelinux8_oracle19c

# 새 이미지로 실행 (컨테이너 기동 시 리스너+DB 자동 시작)
docker run -d \
  --name oraclelinux8_oracle19c \
  --privileged \
  --hostname oraclelinux8-oracle19c \
  -p 1523:1521 \
  oraclelinux8_oracle19c:latest
```

> **--privileged 필수**: 없으면 PAM 세션 오류로 `su - oracle` 불가
> **--hostname 고정**: 없으면 컨테이너 재생성 시 호스트명이 바뀌어 listener.ora 불일치 발생

---

## 12. 기동 확인

```bash
# 로그 확인 (리스너/DB 시작 완료 메시지 확인)
docker logs -f oraclelinux8_oracle19c

# 포트 확인
docker exec oraclelinux8_oracle19c netstat -tlnp | grep 1521

# 접속 테스트
docker exec -it oraclelinux8_oracle19c \
  su - oracle -c "sqlplus system/tiger@localhost:1521/orcl"
```

# Write(entrypoint.sh)

#!/bin/bash

echo ">>> Starting Oracle Listener..."
su - oracle -c "lsnrctl start"

echo ">>> Starting Oracle Database (SID=orcl)..."
su - oracle -c "sqlplus / as sysdba << 'EOF'
startup
EXIT;
EOF"

echo ">>> Oracle 19c Ready. (SID=orcl, PORT=1521)"

# 컨테이너 유지
exec tail -f /dev/null




# Write(Dockerfile)

FROM oraclelinux8_oracle19c

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1521

ENTRYPOINT ["/entrypoint.sh"]



# 도커 이미지 빌드 
docker build -t ol8_oracle19c .


# 마지막 docker run

docker run -itd \
  --name oraclelinux8_oracle19c \
  --privileged \
  --hostname oraclelinux8-oracle19c \
  -p 1523:1521 \
  oraclelinux8_oracle19c:latest


# 필요 시 추가 커밋 

  docker commit oraclelinux8_oracle19c oraclelinux8_oracle19c


  
# 추가 run 테스트 

docker run -itd \
  --name oraclelinux8_oracle19c_2 \
  --privileged \
  --hostname oraclelinux8-oracle19c \
  -p 1525:1521 \
  oraclelinux8_oracle19c:latest