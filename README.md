# Oracle 19c on Oracle Linux 8 Docker

Oracle Linux 8 Docker 이미지에 Oracle Database 19c를 설치하고, 컨테이너 기동 시 자동으로 리스너와 DB가 시작되는 이미지를 빌드하는 전체 가이드입니다.

---

## 환경 정보

| 항목 | 값 |
|------|-----|
| Base Image | oraclelinux:8 |
| Oracle Version | 19c (EE) |
| SID | orcl |
| 리스너 포트 | 1521 |
| sys 비밀번호 | tiger |
| system 비밀번호 | tiger |
| scott 비밀번호 | tiger |
| ORACLE_BASE | /opt/oracle |
| ORACLE_HOME | /opt/oracle/product/19c/dbhome_1 |
| 컨테이너 이름 | oraclelinux8_oracle19c |
| 호스트명 | oraclelinux8-oracle19c |

---

## STEP 1. 초기 컨테이너 실행

```bash
docker pull oraclelinux:8

docker run -d \
  --name oraclelinux8_oracle19c \
  --privileged \
  -p 1521:1521 \
  oraclelinux:8 \
  /bin/bash -c "while true; do sleep 1; done"
```

> RPM 파일을 컨테이너로 복사 (호스트에서 실행)
> ```bash
> docker cp oracle-database-ee-19c-1.0-1.x86_64.rpm oraclelinux8_oracle19c:/tmp/
> ```

```bash
# 컨테이너 접속
docker exec -it oraclelinux8_oracle19c bash
```

---

## STEP 2. 기본 패키지 설치

```bash
dnf update -y
dnf install -y vim
dnf install -y net-tools
dnf install -y hostname
dnf install -y oracle-database-preinstall-19c
```

---

## STEP 3. Oracle Database 19c RPM 설치

```bash
dnf localinstall -y /tmp/oracle-database-ee-19c-1.0-1.x86_64.rpm
```

---

## STEP 4. DB 구성 파일 수정 (SID / 포트 설정)

```bash
vim /etc/sysconfig/oracledb_ORCLCDB-19c.conf
```

아래 내용으로 수정:

```
ORACLE_SID=orcl
ORACLE_PDB=orclpdb
ORACLE_CHARACTERSET=AL32UTF8
LISTENER_PORT=1521
```

---

## STEP 5. 데이터베이스 생성 및 구성

```bash
# 약 10~20분 소요
/etc/init.d/oracledb_ORCLCDB-19c configure
```

---

## STEP 6. oracle 유저 환경 변수 설정

```bash
cat <<'EOT' >> /home/oracle/.bash_profile

# Oracle Settings
export ORACLE_SID=orcl
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin
EOT

source /home/oracle/.bash_profile
```

---

## STEP 7. 계정 비밀번호 설정 및 scott 계정 생성

```bash
su - oracle
sqlplus / as sysdba
```

sqlplus 프롬프트에서:

```sql
ALTER USER sys IDENTIFIED BY tiger;
ALTER USER system IDENTIFIED BY tiger;

CREATE USER scott IDENTIFIED BY tiger;
GRANT CONNECT, RESOURCE TO scott;
ALTER USER scott QUOTA UNLIMITED ON USERS;

EXIT;
```

---

## STEP 8. listener.ora 수정

> `--hostname` 없이 컨테이너를 처음 실행한 경우, listener.ora에 구버전 호스트명이 하드코딩될 수 있음.
> 아래와 같이 고정 호스트명으로 수정.

```bash
vim /opt/oracle/product/19c/dbhome_1/network/admin/listener.ora
```

```
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = oraclelinux8-oracle19c)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )
```

---

## STEP 9. tnsnames.ora 수정

```bash
vim /opt/oracle/product/19c/dbhome_1/network/admin/tnsnames.ora
```

```
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
```

---

## STEP 10. 리스너 시작 및 접속 테스트

```bash
su - oracle
lsnrctl start
lsnrctl status
```

```bash
sqlplus sys/tiger@localhost:1521/orcl as sysdba
sqlplus system/tiger@localhost:1521/orcl
sqlplus scott/tiger@localhost:1521/orcl
```

---

## STEP 11. 자동 시작 이미지 빌드

> 설치 완료된 컨테이너를 커밋 → Dockerfile로 자동 시작 이미지 빌드

```bash
# 현재 컨테이너를 이미지로 커밋
docker commit oraclelinux8_oracle19c oraclelinux8_oracle19c

# Dockerfile 기반 빌드 (Dockerfile, entrypoint.sh 동일 디렉토리 필요)
docker build -t ol8_oracle19c .
```

---

## STEP 12. 자동 시작 컨테이너 실행

```bash
docker rm -f oraclelinux8_oracle19c

docker run -itd \
  --name oraclelinux8_oracle19c \
  --privileged \
  --hostname oraclelinux8-oracle19c \
  -p 1523:1521 \
  ol8_oracle19c
```

> - `--privileged` 필수: 없으면 PAM 세션 오류로 `su - oracle` 불가
> - `--hostname` 고정: listener.ora 호스트명 불일치 방지

---

## STEP 13. 기동 확인

```bash
# 로그 확인 (리스너/DB 자동 시작 메시지)
docker logs -f oraclelinux8_oracle19c

# 포트 확인
docker exec oraclelinux8_oracle19c netstat -tlnp | grep 1521

# 접속 테스트
docker exec -it oraclelinux8_oracle19c \
  su - oracle -c "sqlplus system/tiger@localhost:1521/orcl"
```

---

## 부록: 추가 컨테이너 실행 (포트만 다르게)

```bash
docker run -itd \
  --name oraclelinux8_oracle19c_2 \
  --privileged \
  --hostname oraclelinux8-oracle19c \
  -p 1525:1521 \
  ol8_oracle19c
```

---

## 파일 구성

| 파일 | 설명 |
|------|------|
| `Dockerfile` | 자동 시작 이미지 빌드 정의 |
| `entrypoint.sh` | 컨테이너 시작 시 리스너 → DB 순으로 자동 기동 |
| `script.md` | 작업 과정 메모 |
