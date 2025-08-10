# AGENTS.md (AWS EKS + Kubecost)

## 목적
AWS EKS 환경에 Kubecost를 설치하고 Web Console에서 비용 모니터링이 가능하도록 Helm values(`kubecost.yaml`) 및 관련 리소스를 생성·적용하는 Codex 협업 문서.  
목표는 **비용 시각화·분석·절감 포인트 식별**이며, 설치 후 안정적인 운영과 보안을 고려한다.

---

## 최종 산출물
- `deploy/kubecost/kubecost.yaml` : Kubecost Helm values
- `deploy/kubecost/ingress.yaml` : ALB Ingress 설정
- `deploy/kubecost/irsa.yaml` : IRSA(ServiceAccount + IAM Role)
- `deploy/kubecost/networkpolicy.yaml` : 최소 권한 네트워크 정책
- `reports/kubecost-validate-<timestamp>.md` : 배포 검증 보고서
- `deploy/kubecost/README.md` : 설치 및 운영 가이드

---

## 공통 가정(환경)
- Kubernetes: Amazon EKS (>= 1.26)
- 네임스페이스: `kubecost`
- Helm Chart: `oci://public.ecr.aws/kubecost/cost-analyzer`
- AWS Load Balancer Controller 설치 완료(ALB 사용 가능)
- IRSA(OIDC) 활성화 완료
- StorageClass: `gp2` (AWS EBS 기반)
- Prometheus: 기존 설치 버전 재활용(선택)
- 도메인: `kubecost.jhun80.click` (Route53/ACM 인증서 사용 가능)

---

## 입력 변수
```yaml
clusterName: eks-prod
namespace: kubecost
installMethod: helm-oci
kubecostVersion: "2.8.1"
domain: "kubecost.example.com"
useExistingPrometheus: true
prometheusAddress: "http://prometheus-server.monitoring.svc:80"
storageClass: "gp2"
pvcSize: "50Gi"
enableIRSA: true
awsRegion: "ap-northeast-2"
enableALBIngress: true
albScheme: "internet-facing"
albCertificateArn: "arn:aws:acm:ap-northeast-2:111122223333:certificate/xxxx"
enableNetworkPolicy: true
costSources:
  - kubernetes
  - ebs
  - ec2
  - s3
```

---

## 에이전트 구성

### 1) **K8s 아키텍트**
- **목표**: 클러스터 제약 파악 및 Kubecost 리소스 설계
- **입력**: StorageClass, 노드 리소스, 네임스페이스 정책
- **출력**: PVC/리소스 요청·제한 값
- **체크리스트**
  - [ ] `namespace kubecost` 존재 확인
  - [ ] StorageClass와 PVC 크기 검증
  - [ ] HPA 적용 여부 결정

### 2) **Kubecost 솔루션 스페셜리스트**
- **목표**: `kubecost.yaml`(Helm values) 작성
- **입력**: Prometheus 설정, 스토리지 값, 버전
- **출력**: `deploy/kubecost/kubecost.yaml`
- **체크리스트**
  - [ ] Prometheus 연결 정보 정확성
  - [ ] Persistence 설정 반영
  - [ ] Ingress 기본 설정 적용

### 3) **보안·네트워크**
- **목표**: IRSA, ALB Ingress, NetworkPolicy 설계
- **입력**: ACM ARN, ALB 스킴, AWS IAM 권한
- **출력**: `irsa.yaml`, `ingress.yaml`, `networkpolicy.yaml`
- **체크리스트**
  - [ ] HTTPS 강제
  - [ ] 최소 권한 네트워크 정책
  - [ ] IRSA Role Trust Policy 확인

### 4) **비용 분석가**
- **목표**: 비용 소스 연동 및 태깅 규칙 제시
- **입력**: AWS CUR, 태그 규칙
- **출력**: README.md 운영 체크리스트
- **체크리스트**
  - [ ] 라벨링 규칙(`team`, `env`, `owner`)
  - [ ] 비용 분석 대시보드 초기 확인

### 5) **검증·릴리즈 매니저**
- **목표**: 배포 전후 검증 및 롤백 계획
- **입력**: 모든 산출물
- **출력**: `reports/kubecost-validate-<timestamp>.md`
- **체크리스트**
  - [ ] helm template / dry-run
  - [ ] Ingress 연결 테스트
  - [ ] 브라우저 404 에러 여부 확인

---

## 협업 플로우
1. **수집 단계** (K8s 아키텍트) → 환경 정보·제약 수집
2. **설계/생성** (솔루션 스페셜리스트, 보안·네트워크) → YAML 작성
3. **검증** (릴리즈 매니저) → Dry-run·배포
4. **운영** (비용 분석가) → 대시보드 확인 및 피드백

---

## 에이전트별 프롬프트 템플릿

### (A) K8s 아키텍트
```
당신은 EKS 아키텍트입니다. 입력값을 기반으로 Kubecost의 리소스 요청/제한과 PVC 전략을 제안하세요.
```

### (B) Kubecost 스페셜리스트
```
당신은 Kubecost 전문가입니다. 주어진 환경과 제약을 반영한 Helm values(kubecost.yaml)를 작성하세요.
```

### (C) 보안·네트워크
```
당신은 SRE입니다. IRSA, Ingress(ALB), NetworkPolicy를 최소 권한으로 설계하세요.
```

---

## 가드레일
- ALB는 HTTPS만 허용, ACM 인증서 적용 필수
- PVC 크기 최소 20Gi, 운영 50Gi 이상 권장
- 리소스 requests/limits 반드시 설정
- IRSA 미사용 시 IAM Role 의존 경고 문서화
- 외부 egress 최소화

---

## 샘플 산출물 스니펫
```yaml
kubecostModel:
  persistence:
    enabled: true
    storageClass: "gp3"
    size: "50Gi"
```

---

## 검증 단계
- `helm template` → `kubectl apply --dry-run=server`
- ALB DNS와 HTTPS 접속 확인
- 대시보드 Allocation, Assets, Savings 정상 로드 확인

---

## 실패 모드 & 대응
- **CrashLoopBackOff**: Service 포트/Ingress 경로 확인
- **PVC 바인딩 실패**: StorageClass와 크기 확인
- **404 에러**: Ingress 서비스 매핑 확인

---

## 운영 체크리스트
- 네임스페이스/워크로드 태그 규칙 준수
- 월간 비용 보고 생성
- 미사용 리소스 정리 프로세스 운영

---

## 적용/롤백 명령
- 적용:
```bash
helm upgrade -i kubecost oci://public.ecr.aws/kubecost/cost-analyzer \
  --version 2.8.1 -n kubecost \
  -f deploy/kubecost/kubecost.yaml --create-namespace
```
- 롤백:
```bash
helm rollback kubecost <REVISION> -n kubecost
```
