# DevOps 실습 Tips

> Terraform → Ansible → EKS → GitHub Actions 연동 시 놓치기 쉬운 것들 정리

---

## 1. Terraform 태그 → Ansible 동적 인벤토리 연동

Ansible의 `aws_ec2` 플러그인은 **AWS 태그**를 기준으로 호스트를 필터링하고 그룹을 만든다.
Terraform에서 태그를 잘못 설정하면 Ansible이 노드를 아예 찾지 못한다.

### Terraform에서 반드시 설정할 태그 (EKS Node Group)

```hcl
# modules/eks/main.tf
resource "aws_eks_node_group" "this" {
  ...
  tags = {
    "Environment"                               = var.environment   # "prod"
    "Project"                                   = "ticketing"
    "Role"                                      = "eks-node"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"           # EKS 필수 태그
  }
}
```

### Ansible aws_ec2.yml에서 매칭

```yaml
# inventory/aws_ec2.yml
plugin: amazon.aws.aws_ec2
filters:
  tag:Project: ticketing
  tag:Role: eks-node
  tag:Environment: prod          # Terraform 태그와 반드시 일치해야 함
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: tags.Environment
    prefix: env
```

이렇게 하면 Ansible 내에서 `role_eks_node`, `env_prod` 같은 그룹으로 자동 분류된다.

---

## 2. Terraform 작업 순서 (의존성)

리소스 간 의존성이 있어서 순서를 틀리면 에러가 난다.

```
1. S3 버킷 + DynamoDB (state 저장용) → 수동 1회 생성 or 별도 bootstrap 폴더
2. VPC / Subnet / IGW / NAT
3. Security Group
4. RDS, ElastiCache (VPC 안에 위치)
5. ECR (독립적이라 어디서든 가능)
6. EKS Cluster
7. EKS Node Group (Cluster가 먼저 있어야 함)
8. IAM OIDC Provider (GitHub Actions IRSA용 - Cluster 생성 후)
```

> **주의**: `backend.tf`에 S3 버킷 이름을 쓰는데, 그 버킷이 존재해야 `terraform init`이 된다.
> 첫 실행 시 닭-달걀 문제가 생기므로 backend 버킷은 AWS 콘솔이나 별도 스크립트로 먼저 만든다.

---

## 3. Security Group: Ansible SSH 접근

Terraform으로 EKS 노드 Security Group을 만들 때 **Ansible 실행 머신의 IP에서 22번 포트**를 허용하지 않으면 Ansible이 연결 자체를 못 한다.

```hcl
# modules/eks/main.tf
resource "aws_security_group_rule" "ansible_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.ansible_runner_cidr]  # GitHub Actions runner IP or Bastion IP
  security_group_id = aws_security_group.eks_nodes.id
}
```

> EKS 노드는 보통 **Private Subnet**에 있어서 직접 SSH가 안 된다.
> Bastion Host (점프 서버) 또는 AWS SSM Session Manager를 통해 접근하는 것이 실무 표준.

---

## 4. Ansible SSH 키 → Terraform Key Pair 연동

Terraform으로 EC2 Key Pair를 만들고, 그 키를 Ansible이 사용해야 한다.

```hcl
# Terraform에서 키 생성
resource "aws_key_pair" "eks_nodes" {
  key_name   = "ticketing-eks-nodes"
  public_key = file("~/.ssh/ticketing.pub")   # 로컬 공개키
}
```

```ini
# Ansible ansible.cfg 또는 inventory에서
[defaults]
private_key_file = ~/.ssh/ticketing   # 대응하는 개인키
remote_user = ec2-user                # Amazon Linux 2 기본 유저
```

---

## 5. EKS kubeconfig 업데이트

Terraform으로 EKS를 만든 뒤 `kubectl`이나 Ansible의 k8s 모듈을 쓰려면 kubeconfig를 업데이트해야 한다.

```bash
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name ticketing-prod-cluster    # Terraform output의 cluster_name
```

GitHub Actions에서도 배포 전에 이 커맨드를 실행해야 한다.

```yaml
# .github/workflows/deploy-prod.yml
- name: Update kubeconfig
  run: |
    aws eks update-kubeconfig \
      --region ${{ secrets.AWS_REGION }} \
      --name ${{ secrets.EKS_CLUSTER_NAME }}
```

---

## 6. GitHub Actions → AWS 인증 (OIDC 권장)

Access Key를 GitHub Secrets에 저장하는 방법은 쓰지 않는다.
**OIDC(OpenID Connect)** 를 통해 임시 자격증명을 받는 것이 실무 표준.

```
Terraform으로 설정할 것:
1. IAM OIDC Identity Provider (GitHub용)
2. IAM Role (GitHub Actions가 Assume할 Role)
3. Role에 필요한 Policy 연결 (ECR push, EKS 접근 등)
```

```yaml
# .github/workflows/build-push.yml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/github-actions-role
    aws-region: ap-northeast-2
```

> Access Key 방식을 쓰면 키 유출 시 대형사고. OIDC는 임시 토큰이라 훨씬 안전.

---

## 7. ECR 주소 일관성

ECR 리포지토리 URL은 여러 곳에서 사용된다. 하드코딩하지 말고 공통 변수로 관리.

```
형식: {AWS_ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/{REPO_NAME}
예:   123456789.dkr.ecr.ap-northeast-2.amazonaws.com/ticketing-backend
```

```hcl
# Terraform output으로 노출
output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}
```

```yaml
# GitHub Actions에서 사용
ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
IMAGE_TAG: ${{ github.sha }}
```

```yaml
# Kubernetes deployment.yaml에서 참조
image: 123456789.dkr.ecr.ap-northeast-2.amazonaws.com/ticketing-backend:${IMAGE_TAG}
```

---

## 8. Kubernetes Namespace 일관성

Namespace 이름이 K8s 매니페스트, Helm values, GitHub Actions 배포 커맨드에서 전부 동일해야 한다.

```
# 이 세 곳의 namespace 이름이 반드시 일치
Kubernetes/base/namespace.yaml        → metadata.name: ticketing
Kubernetes/base/deployment.yaml       → namespace: ticketing
Kubernetes/helm/monitoring/values.yml → namespace: monitoring
.github/workflows/deploy-prod.yml     → kubectl apply -n ticketing
```

---

## 9. Terraform Remote State 출력값 → 다른 도구 전달

Terraform이 만든 리소스 정보(EKS 클러스터 이름, RDS 엔드포인트 등)를 다른 도구에 전달하는 방법.

```hcl
# environments/prod/outputs.tf에 정의
output "eks_cluster_name"    { value = module.eks.cluster_name }
output "rds_endpoint"        { value = module.rds.endpoint }
output "ecr_repository_url"  { value = module.ecr.repository_url }
```

```bash
# 값 조회
terraform output -raw eks_cluster_name

# GitHub Actions에서 활용
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
```

---

## 10. AWS 리전 하나로 통일

모든 도구에서 리전이 달라지면 리소스를 못 찾는다.

| 도구 | 리전 설정 위치 |
|---|---|
| Terraform | `variables.tf`의 `aws_region` 변수 |
| Ansible | `group_vars/all.yml`의 `aws_region` |
| GitHub Actions | `secrets.AWS_REGION` |
| kubectl / aws cli | `~/.aws/config` 또는 환경변수 `AWS_DEFAULT_REGION` |

> **ap-northeast-2** (서울) 로 전부 통일해두고 시작하는 것을 권장.

---

## 11. .gitignore 반드시 설정

```gitignore
# Terraform
**/.terraform/
*.tfstate
*.tfstate.backup
*.tfvars          # 시크릿이 들어있을 수 있음
.terraform.lock.hcl  # 선택 (팀 작업 시엔 커밋 권장)

# Ansible
*.retry
inventory/hosts    # 동적 인벤토리 사용 시 불필요

# 공통
.env
*.pem
*.key
```

---

## 12. 자주 하는 실수 모음

| 실수 | 증상 | 해결 |
|---|---|---|
| Terraform 태그 오타 | Ansible이 호스트 0개 탐지 | `aws_ec2.yml` 태그 필터와 Terraform 태그 비교 |
| EKS kubeconfig 미갱신 | `kubectl` 연결 거부 | `aws eks update-kubeconfig` 재실행 |
| ECR 로그인 안 함 | Docker pull 401 에러 | `aws ecr get-login-password \| docker login` |
| S3 backend 버킷 없음 | `terraform init` 실패 | 버킷 먼저 수동 생성 |
| IAM 권한 부족 | GitHub Actions에서 403 | OIDC Role에 필요한 Policy 추가 |
| Security Group 22 미개방 | Ansible SSH timeout | SG 인바운드 규칙 확인 |
| Namespace 불일치 | Pod가 다른 ns에 뜸 | 매니페스트와 `kubectl apply -n` 일치 확인 |
