# Install k8s standalone cluster using kubespary on centos7
- Kubespary를 이용하여 kubernetes를 설치하는 과정을 정리
- 주요 체크 사항으로 standalone(1대)으로 master/worker를 동시에 설치하여 정상 동작 확인
- gpu가 탑재된 node에서 k8s의 pod가 정상적으로 gpu driver를 인식하고, gpu를 할당 받는지 확인 
  - "Install_gpu_node.md"파일에 정의 
- 참고 
  - https://medium.com/@cagri.ersen/production-ready-kubernetes-installation-with-kubespray-97063e8a846c
  - https://kubernetes.io/docs/setup/production-environment/tools/kubespray/
  - https://dzone.com/articles/kubespray-10-simple-steps-for-installing-a-product


## STEP 1. Install ansible on mac
- https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html 참고
```
> brew install ansible
> ansible --version
ansible 2.9.6
  config file = None
  configured module search path = ['/Users/skiper/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/local/lib/python3.8/site-packages/ansible
  executable location = /usr/local/bin/ansible
  python version = 3.8.4 (default, Jul 14 2020, 02:58:48) [Clang 11.0.3 (clang-1103.0.32.62)]
```
### Error (Unexpected Exception, this is probably a bug: cannot pickle '_io.TextIOWrapper' object)
#### Problem
- ansible-playbook 실행시 위와 같은 에러가 발생함. (기존 잘 동작하던 코드)
#### Cause
- https://github.com/trailofbits/algo/issues/1622
- kubespary v2.11.2 버전의 ansbile 버전은 2.7.12임. 
- anbile 2.7.2버전과 python 3.8 이상에서 발생하는 문제이므로,
- ansible 2.9로 업데이트 
- pip install --user ansible==2.9.6

## STEP 2. Set kubespary environment on mac 
### Download kubespary code from github
```
> mkdir ~/apps
> cd ~/apps 
> git clone https://github.com/kubernetes-sigs/kubespray.git
> git clone -b v2.13.1 https://github.com/kubernetes-sigs/kubespray.git
> cd kubespray/
> y
> sudo pip3 install -r requirements.txt
```

### Set K8s configurations 
- 샘플로 제공되는 inventory(hosts, variables)정보를 복사한다.
```
> cp -rfp inventory/sample inventory/my-standalone-cluster
```
- 아래 config 파일의 항목 중에서 자신에게 필요한 설정을 수정한다. 
  - group_vars/all : kubernetes 설치에 필요한 기본 설정
    - kube_read_only_port: 10255 
      * kubelet 설정으로 kubelet이 인증/권한 확인 없이 서비스 가능한 설정 
      * https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
    - kube_version: v1.15.4 or v1.16.11
  - group_vars/k8s_cluster : network 및 addnon과 관련된 설정
    - 인증, calico/weave 등 네트워크 결정 
  - group_vars/etcd.yml : etcd 설치와 관련된 설정 
  - inventory.ini : k8s를 설치할 서버 정보 (user_id, user_pw, ssh_ip, ssh_port 등)

#### Update Host info to install kubernetes  
- 설치할 kubernetes 서버의 master/worker/etcd 구성을 정한다. 
- Template로 제공되는 inventory를 복사하여 내 환경에 맞는 설정으로 구성한다. 
- 나의 경우 Standalone 방식으로 하나의 서버에 k8s master, worker, etcd등 전부 설치 
```
> vi inventory/my-standalone-cluster/inventory.ini
[all]
node1 ansible_ssh_port=22  ansible_host="GCP 외부 IP"  ip="GCP인 경우 내부 IP"   ansible_user=freepsw  etcd_member_name=etcd1

[kube-master]
node1

[etcd]
node1

[kube-node]
node1

[calico-rr]

[k8s-cluster:children]
kube-master
kube-node
calico-rr
``` 
- 위에서 gcp 내부 ip를 사용하지 않는 경우 "Stop if ip var does not match local ips" 단계에서 에러가 발생함

## STEP 3-1. Pre-Install on all nodes
### Install necessary libraries using yum
- sshpass를 설치하지 않으면, "prep_kubeadm_images | Error copying kubeadm binary from download dir to system path" 에러 발생 (prep_kubeadm_images.yaml 파일)
```
> sudo yum install -y sshpass
> sudo yum install -y java-11-openjdk
# https://github.com/ansiblebit/oracle-java/blob/master/defaults/redhat.yml 참고
# https://phoenixnap.com/kb/install-java-on-centos
```


## STEP 3-2 (Optional). Setting the configurations of noedes to install kubernetes 
- kubernetes를 설치하기 위해서는 각 노드에 필수적으로 설정해야 할 구성이 있다. 
- kubespary에서는 roles/kubernetes/node 라는 role에서 필요한 작업을 자동으로 수행한다. 
- 그 중 가장 중요하게 해야할 작업을 확인해 보면 노드별로 아래와 같이 확인 가능하다. 
- 이 모든 설정은 kubespary가 자동으로 진행함. (참고만)
###  On all K8s Node 
```
> setenforce 0
> sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
```
- 가능하다면 아래처럼 특정 port만 방화벽을 해제하는 것이 아니라,
- 전체 방화벽을 해제하는 것이 운영하기 쉽다. (보안상의 이슈로 보통은 특정 포트만 오픈)
```
> sudo systemctl stop firewalld
> sudo systemctl disable firewalld
```

### On k8s master nodes
```
> firewall-cmd --permanent --add-port=6443/tcp
> firewall-cmd --permanent --add-port=2379-2380/tcp
> firewall-cmd --permanent --add-port=10250/tcp
> firewall-cmd --permanent --add-port=10251/tcp
> firewall-cmd --permanent --add-port=10252/tcp
> firewall-cmd --permanent --add-port=10255/tcp
> firewall-cmd --reload

# br_netfilter 모듈을 사용하면 브릿지를 통과하는 패킷이 필터링 및 포트 전달을 위해 iptables에 의해 처리되고 클러스터의 쿠버네티스 Pod는 서로 통신 가능.
> modprobe br_netfilter
> echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
> sysctl -w net.ipv4.ip_forward=1
```

### On k8s worker nodes
```
> firewall-cmd --permanent --add-port=10250/tcp
> firewall-cmd --permanent --add-port=10255/tcp
> firewall-cmd --permanent --add-port=30000-32767/tcp
> firewall-cmd --permanent --add-port=6783/tcp
> firewall-cmd  --reload
> echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
> sysctl -w net.ipv4.ip_forward=1
```


## STEP 4. Run ansible-playbook 
- kubespary에서는 기본으로 k8s를 설치/확장/제거에 필요한 yml을 제공한다. 
  - cluster.yml
  - scale.yml
  - reset.yml
  - remove-node.yml
  - reset.yml
  - revoer-control-plane.yml 
  - upgrade-cluster.yml 
  - mitogen.yaml : 이 설정은 k8s가 아닌 ansible의 배포 성능 향상을 위한 task를 정의함. 


### Create k8s cluster 
```
# 1. kubernetes cluster 설정
> ansible-playbook -i inventory/my-standalone-cluster/inventory.ini cluster.yml -b -v \
  --private-key=~/.ssh/gcp-freepsw-sk
```

### post-install 추가
- kubespary로 설치후 추가로 필요한 작업을 실행하기 위한 별도의 task를 추가한다. 
- kubectl 경로, gpu 노드의 taint 제거 등
- 0.cluster_post_task.yml

- task 실행
```
> ansible-playbook -i inventory/my-standalone-cluster/inventory.ini 0.cluster_post_task.yml -b -v \
  --private-key=~/.ssh/gcp-freepsw-sk
```


### Error 1. Minimum supported kubernetes version 
#### Error 
- "The current release of Kubespray only support newer version of Kubernetes than v1.16.0 - You are trying to apply v1.15.4"
#### Cause 
- roles/kubespray-defaults/defaults/main.yaml에 "kube_version_min_required: v1.16.0"으로 설정됨.
- kubespary의 배포 버전 중 2.13.0 이상은 지원하는 kubernetes 최소 버전이 v1.16.0 이상 
#### Solved 
- 따라서 kubernetes v1.15을 지원하는 kubespary v.2.12.7을 설치하여 해결 

### Error 2 ansible ip erro
#### Error : nsible_all_ipv4_addresses의 ip가 현재 server의 ip와 맞지 않음. 
```
TASK [kubernetes/preinstall : Stop if ip var does not match local ips] ****************************************************************************************
Monday 27 July 2020  13:03:58 +0900 (0:00:00.094)       0:00:28.244 ***********
fatal: [node1]: FAILED! => {
    "assertion": "ip in ansible_all_ipv4_addresses",
    "changed": false,
    "evaluated_to": false,
    "msg": "Assertion failed"
}


TASK [kubernetes/preinstall : Check ip ADDRESS] ***************************************************************************************************************
Monday 27 July 2020  13:03:58 +0900 (0:00:00.096)       0:00:28.058 ***********
ok: [node1] => {
    "ansible_all_ipv4_addresses": [
        "10.178.0.25"
    ]
}

TASK [kubernetes/preinstall : debug] **************************************************************************************************************************
Monday 27 July 2020  13:03:58 +0900 (0:00:00.092)       0:00:28.150 ***********
ok: [node1] => {
    "ip": "10.178.0.35"
}
```

#### Cause 
- ansible에서 설치할 node에 대한 정보를 조회하여 fact라는 형태로 저장하게 된다. 
- 위 에러는 기존에 fact로 저장했던 변수 중 ansible_all_ipv4_addresses의 값이 갱신되지 않아서 발생하는 에러
- kubespary v2.13.1 부터는 fact를 갱신하는 task가 있는데, 
- kubespary v2.12.7 이전에는 해당 로직이 없다. 

#### Solve 
- ansible fact를 갱신하는 task를 추가한다. 
- cluster.yml 에 fact를 수집하는 task 파일을 imort한다. 
```yml 
# 기존 ansibile fact를 다시 갱신하기 위해서 추가 
- name: Gather facts
  tags: always
  import_playbook: ./00.my_custom_task/gather_facts.yml
```
- fact.yml (실제 fact를 수집하는 task 정의)
```yml
---
- name: Gather facts
  hosts: k8s-cluster:etcd:calico-rr
  gather_facts: False
  tasks:
    - name: Gather minimal facts
      setup:
        gather_subset: '!all'

    - name: Gather necessary facts
      setup:
        gather_subset: '!all,!min,network,hardware'
        filter: "{{ item }}"
      loop:
        - ansible_distribution_major_version
        - ansible_default_ipv4
        - ansible_all_ipv4_addresses
        - ansible_memtotal_mb
        - ansible_swaptotal_mb
```

### Error3. {"changed": false, "cmd": "sshpass", "msg": "[Errno 2] 그런 파일이나 디렉터리가 없습니다", "rc": 2}
#### Cause 
- roles/kubernetes/node/tasks/install.yml의 아래 synchronize 모듈 사용시 발생
```yaml
- name: install | Copy kubeadm binary from download dir
  synchronize:
    src: "{{ local_release_dir }}/kubeadm-{{ kubeadm_version }}-{{ image_arch }}"
    dest: "{{ bin_dir }}/kubeadm"
```
#### Solve 
- 관련된 노드에 sshpass 설치 
```
> yum install -y sshpass
```




## STEP 5. Test the installed kubenetes
- root 계정으로 설치되었으므로, 사용자 계정으로 실행하면 아래와 같은 오류가 발생한다. 
- "The connection to the server localhost:8080 was refused - did you specify the right host or port?" 
```
> sudo -i 
> /usr/local/bin/kubectl get po

# 위와 같이 kubectl의 path를 가져오지 못하므로, 설정에 path를 추가한다. 
> vi ~/.bash_profile
alias kubectl='/usr/local/bin/kubectl'

> source ~/.bash_profile
> kubectl get po
No resources found in default namespace.

> kubectl apply -f https://k8s.io/examples/controllers/nginx-deployment.yaml
> kubectl get deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3/3     3            3           15s
```







## ETC 
### Get kubernetes resource usage 
- 아래의 script를 통해 전체 node의 자원 사용량 확인 가능
- vi node-resources.sh 
```shell
#!/bin/bash
set -euo pipefail

echo -e "Iterating...\n"

nodes=$(kubectl get node --no-headers -o custom-columns=NAME:.metadata.name)

for node in $nodes; do
  echo "Node: $node"
  kubectl describe node "$node" | sed '1,/Non-terminated Pods/d'
  echo
done
```
- 아래와 같이 Node별 사용량 확인 가능
```
> ./node-resources.sh 

  kube-system                kube-apiserver-master              250m (6%)     0 (0%)      0 (0%)           0 (0%)         12d
  kube-system                kube-controller-manager-master     200m (5%)     0 (0%)      0 (0%)           0 (0%)         12d
  kube-system                kube-proxy-ss85w                   0 (0%)        0 (0%)      0 (0%)           0 (0%)         12d
  kube-system                kube-scheduler-master              100m (2%)     0 (0%)      0 (0%)           0 (0%)         12d
  kube-system                nodelocaldns-hrk6l                 100m (2%)     0 (0%)      70Mi (0%)        170Mi (1%)     12d
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests        Limits
  --------           --------        ------
  cpu                920m (24%)      300m (7%)
  memory             221286400 (1%)  856515840 (5%)
  ephemeral-storage  0 (0%)          0 (0%)
Events:              <none>

Node: node1
  Namespace                  Name                                        CPU Requests  CPU Limits    Memory Requests  Memory Limits     AGE
  ---------                  ----                                        ------------  ----------    ---------------  -------------     ---
  istio-system               cluster-local-gateway-749864569-vlt9t       100m (2%)     2 (51%)       128Mi (0%)       1Gi (7%)          6h14m
  istio-system               grafana-74dc798895-wj4hl                    10m (0%)      0 (0%)        0 (0%)           0 (0%)            6h14m
  istio-system               istio-ingressgateway-bc484884-df7zf         100m (2%)     2 (51%)       128Mi (0%)       1Gi (7%)          6h14m
  istio-system               istio-telemetry-6955b4cbd4-gjf9d            1100m (28%)   6800m (174%)  1134217728 (7%)  5073741824 (33%)  6h14m
  istio-system               istio-tracing-8584b4d7f9-jwtmk              10m (0%)      0 (0%)        0 (0%)           0 (0%)            6h14m
  istio-system               istiod-5fd879956c-fwphw                     500m (12%)    0 (0%)        2Gi (14%)        0 (0%)            6h14m
  istio-system               istiod-7c7c65dff7-hr8z8                     500m (12%)    0 (0%)        2Gi (14%)        0 (0%)            6h19m
  istio-system               kiali-6f457f5964-sp4jr                      10m (0%)      0 (0%)        0 (0%)           0 (0%)            6h14m
  istio-system               prometheus-77f78d599d-j8nqz                 10m (0%)      0 (0%)        0 (0%)           0 (0%)            6h14m
  kube-system                calico-kube-controllers-64d7594b96-sx8qz    30m (0%)      100m (2%)     64M (0%)         256M (1%)         12d
  kube-system                calico-node-nmmzc                           150m (3%)     300m (7%)     64M (0%)         500M (3%)         12d
  kube-system                coredns-58687784f9-cq4xr                    100m (2%)     0 (0%)        70Mi (0%)        170Mi (1%)        12d
  kube-system                kube-proxy-xwlss                            0 (0%)        0 (0%)        0 (0%)           0 (0%)            12d
  kube-system                kubernetes-dashboard-556b9ff8f8-rmkp8       50m (1%)      100m (2%)     64M (0%)         256M (1%)         12d
  kube-system                nginx-proxy-node1                           25m (0%)      0 (0%)        32M (0%)         0 (0%)            12d
  kube-system                nodelocaldns-85v9d                          100m (2%)     0 (0%)        70Mi (0%)        170Mi (1%)        12d
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests          Limits
  --------           --------          ------
  cpu                2795m (71%)       11300m (289%)
  memory             6068421120 (39%)  8589741312 (56%)
  ephemeral-storage  0 (0%)            0 (0%)
Events:              <none>
```


- GKE Cluster 확인 예시
```

Node: gke-kfserving-dev-gpu-k80-nodepool-e2470feb-pczb
  Namespace                   Name                                                           CPU Requests  CPU Limits   Memory Requests  Memory Limits  AGE
  ---------                   ----                                                           ------------  ----------   ---------------  -------------  ---
  auto-create-23              hm-model-predictor-default-q59k4-deployment-664657c-lk826      1100m (13%)   1200m (15%)  6344Mi (23%)     6644Mi (25%)   85m
  knative-monitoring          node-exporter-2z6v4                                            110m (1%)     220m (2%)    50Mi (0%)        90Mi (0%)      5d7h
  kube-system                 fluentd-gcp-v3.1.1-k5q5z                                       100m (1%)     1 (12%)      200Mi (0%)       500Mi (1%)     5d7h
  kube-system                 gke-metadata-server-9kksn                                      100m (1%)     100m (1%)    100Mi (0%)       100Mi (0%)     5d7h
  kube-system                 kube-proxy-gke-kfserving-dev-gpu-k80-nodepool-e2470feb-pczb    100m (1%)     0 (0%)       0 (0%)           0 (0%)         5d7h
  kube-system                 netd-j5b7b                                                     0 (0%)        0 (0%)       0 (0%)           0 (0%)         5d7h
  kube-system                 nvidia-driver-installer-wwpvl                                  150m (1%)     0 (0%)       0 (0%)           0 (0%)         5d7h
  kube-system                 nvidia-gpu-device-plugin-jfkd7                                 50m (0%)      50m (0%)     10Mi (0%)        10Mi (0%)      5d7h
  kube-system                 prometheus-to-sd-srbt7                                         1m (0%)       3m (0%)      20Mi (0%)        37Mi (0%)      5d7h
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource                   Requests      Limits
  --------                   --------      ------
  cpu                        1711m (21%)   2573m (32%)
  memory                     6724Mi (25%)  7381Mi (27%)
  ephemeral-storage          0 (0%)        0 (0%)
  hugepages-1Gi              0 (0%)        0 (0%)
  hugepages-2Mi              0 (0%)        0 (0%)
  attachable-volumes-gce-pd  0             0
  nvidia.com/gpu             1             1
Events:                      <none>

freepsw@cloudshell:~ (ds-ai-platform)$
```


### Setting for on-prem 
```
> yum install python-netaddr
```