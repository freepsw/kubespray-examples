# Add gpu node using kubespary (how to set kubespary configurations for gpu node) 
- kubespary에서 gpu가 탑재된 노드를 지정하여, 필요한 그래픽 드라이버 및 k8s pod를 생성하는 방법 
- https://linuxconfig.org/how-to-install-the-nvidia-drivers-on-centos-7-linux
- Kubernetes on NVIDIA GPU Documentation
- https://docs.nvidia.com/datacenter/kubernetes/kubernetes-upstream/index.html

## STEP 1. Check GPU info of nodes 
- k8s에 추가할 gpu노드에 장착된 gpu 카드에 대한 정보를 확인한다. 
- 기본적으로 gpu type과 버전이 있어야, 해당하는 그래픽 드라이버를 k8s node에 설치가능함. 
### Check GPU information at nvidia web site
- https://www.nvidia.com/Download/driverResults.aspx/162630/en-us
- cuda version에 따라서 gpu driver의 정보가 달라진다. (본인의 GPU 카드에 맞는 정보를 선택한다.)
  - [Tesla v100 gpu에서 cuda 10.2] 버전을 선택한 경우 그래픽 드라이버 정보
  ```
  Version:	440.95.01
  Release Date:	2020.6.24
  Operating System:	Linux 64-bit
  CUDA Toolkit:	10.2
  Language:	English (US)
  File Size:	137 MB
  ```

  - [Tesla v100 gpu에서 cuda 11.0] 버전을 선택한 경우 
  ```
  Version:	450.51.06
  Release Date:	2020.7.28
  Operating System:	Linux 64-bit
  CUDA Toolkit:	11.0
  Language:	English (US)
  File Size:	136.47 MB
  ```

## STEP 2. Install the nvidia graphic driver on host (worker node).
- k8 nvidia 실행을 지원하는 pod(nvidia-driver-installer-smnhl)가 정상 실행될 수 있도록,
- 물리 서버(GPU node)에 Nvidia driver가 설치되어 있어야 한다. 
  - https://developer.nvidia.com/cuda-toolkit-archive 참고 
### 기존 버전(nvidia 버전(418.87.00))이 있는 경우, 서버 reboot 할때 자동으로 이 로드되지 않도록 시스템에서 삭제
- https://docs.nvidia.com/cuda/index.html 참고 (host에 nvidia driver 설치)
- https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#install-guide (컨테이너에 nvidia 환경 구성을 위한 설정)

```
# RHEL7/CentOS7
# To remove CUDA Toolkit:
> sudo yum remove "cuda*" "*cublas*" "*cufft*" "*curand*" \
 "*cusolver*" "*cusparse*" "*npp*" "*nvjpeg*" "nsight*"

# To remove NVIDIA Drivers:
> sudo yum remove "*nvidia*" 
```

### nvidia 설치 (450.51.06) : 현재 가장 최신 버전은 450.80.02
  - https://www.nvidia.com/Download/driverResults.aspx/165294/en-us
  - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#pre-installation-actions
```
# 2.1. Verify You Have a CUDA-Capable GPU
> yum install -y pciutils
> lspci | grep -i nvidia
18:00.0 3D controller: NVIDIA Corporation GV100GL [Tesla V100 PCIe 32GB] (rev a1)

# 2.2. Verify You Have a Supported Version of Linux
>  uname -m && cat /etc/*release
x86_64
CentOS Linux release 7.8.2003 (Core)

# 2.3. Verify the System Has gcc Installed
> gcc --version
gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-39)

# 2.4. Verify the System has the Correct Kernel Headers and Development Packages Installed
# 커널 버전에 맞는 kernel header와 development package가 설치되어 있어야 한다. 
> uname -r
3.10.0-1160.2.2.el7.x86_64

> sudo yum install kernel-devel-$(uname -r) kernel-headers-$(uname -r)

# 제대로 설치되었는지 확인해 본다. 
> yum list installed | grep kernel-devel-*
kernel-devel.x86_64                  3.10.0-1160.2.2.el7               @updates

> yum list installed | grep kernel-headers-*
kernel-headers.x86_64                3.10.0-1160.2.2.el7               @updates

# 2.6. Download the NVIDIA CUDA Toolkit
# https://developer.nvidia.com/cuda-toolkit-archive
# cuda vs nvidia driver 버전간 호환성 매트릭스 (https://docs.nvidia.com/deploy/cuda-compatibility/index.html)
# 서로 major 버전이 다를 경우 오류가 발생할 수 있으므로, 버전을 확인하고 설치한다. 
# 여기서는 nvidia version(k8s pod에 설치되는 버전)과 cuda version을 동일하게 설치함.
> wget https://developer.download.nvidia.com/compute/cuda/11.0.3/local_installers/cuda_11.0.3_450.51.06_linux.run

# 설치시 옵션에서 nvidia driver를 선택하지 말아야 함. 
# cuda driver만 선택하여 설치해야, kubernetes pod(nvidia-driver-installer)에서 오류가 발생하지 않음. 
> sudo sh cuda_11.0.3_450.51.06_linux.run


# 2.7 To uninstall the CUDA Toolkit, run cuda-uninstaller in /usr/local/cuda-11.0/bin
# To uninstall the NVIDIA Driver, run nvidia-uninstall

> cd /usr/local/cuda-11.0/bin
> ./cuda-uninstaller

```

## STEP 3. Enable GPU options in variables settings.
- Kubespary는 ansible role 기반으로 구성되어 있으므로,
- 어떤 role에서 gpu관련 task를 수행하는지 확인이 필요하고,
- GPU 설정을 위해서 어떤 variable을 변경해야 하는지 확인해야 한다. 
- 
### Kubespary에서 GPU 관련 변수 설정 확인하기 
- kubespray에 별도의 GPU설정을 위한 가이드가 없어서 
- 일단 gpu관련된 설정을 모두 찾아 보았다. 
- ansible은 중복된 변수가 있을 변수가 선언된 위치에 따라 우선순위를 가지는데, 
- 아래는 우선순위 기준으로 정리해 보았다. 
```
1. inventory/my-standalone-cluster/group_vars/k8s-cluster/k8s-cluster.yml 
- kubernetes 전체 role에서 참고하는 변수 

2. inventory/my-standalone-cluster/group_vars/all/docker.yaml
- docker관련된 모든 설정을 관리하는 변수
- ubuntu에서 gpu를 사용하기 위해서는 docker storage를 overlay2로 설정해야 한다. 
- 모든 linux에서 가능하면 docker storage는 overlay2를 사용하는 것을 권장함. 

3. roles/kubernetes-apps/container_engine_accelerator/nvidia_gpu/defaults/main.yml
- kubernetes node에 nvidia gpu device plugin을 설치를 위해 필요한 설정
```


#### 1. inventory/my-standalone-cluster/group_vars/k8s-cluster/k8s-cluster.yml 
- Kubernetes 관련 전체 설정에 영향을 미침.
```yml 
## Container Engine Acceleration
## Enable container acceleration feature, for example use gpu acceleration in containers
nvidia_accelerator_enabled: true

## Nvidia GPU driver install. Install will by done by a (init) pod running as a daemonset.
## Array with nvida_gpu_nodes, leave empty or comment if you don't want to install drivers.
## Labels and taints won't be set to nodes if they are not in the array.
## 여기서 지정한 node의 목록은 k8s에서 gpu node에 label과 taint를 지정하기 위한 용도로 사용된다. 
## 만약 아래 노드들을 지정하지 않으면 k8s 노드에 gpu를 위한 label/taint를 지정하지 않게 된다. 
## 여기서 정의한 node에 gpu를 driver를 설정하고, gpu 용도가 아닌 작업은 실행하지 못하도록 taint를 설정한다. 
nvidia_gpu_nodes:
  - node1
```
#### 2. inventory/my-standalone-cluster/group_vars/all/docker.yaml
```yml
## Uncomment this if you want to force overlay/overlay2 as docker storage driver
## Please note that overlay2 is only supported on newer kernels
docker_storage_options: -s overlay2
```
##### Docker storage 유형 
- overlay2 : 모든 리눅스 배포판에 권장하는 스토리지. (별도의 설정없이 사용가능)
  - Overlay2 Storage 적용 제약사항
    - https://docs.docker.com/storage/storagedriver/overlayfs-driver/
    - Docker Engine : Community, and Docker EE 17.06.02-ee5 이상
    - Linux Kernel version : Ubuntu v4.0 or higher of the Linux kernel, RHEL or CentOS using version 3.10.0-514 
- aufs : Old 버전(18.06 이전) docker에 권장하던 방식. (Ubuntu 14.04 on kernel 3.13)
- devicemapper : direct-lvm을 추가구성하는 방식으로 centos/rhel 리눅스에 권장하는 방식 
  - 기존 centos의 커널이 overlay2를 지원하지 않아서, 이 방식을 사용했으나,
  - 현재 centos 커널이 overlay2를 지원하므로 overlay2 사용을 권장 
  - https://docs.docker.com/storage/storagedriver/select-storage-driver/

- btrfs, zfs : 기존 docker가 설치된 서버의 파일시스템인 경우 그대로 사용.
  - 운영 및 관리를 위한 추가적인 작업이 많이 필요하다.
- vfs : 테스트 목적으로 구성하는 스토리지로 성능이 많이 낮음

#### 3. roles/kubernetes-apps/container_engine_accelerator/nvidia_gpu/defaults/main.yml
- 
```yml
# kubernetes에서 nvidia driver를 활성화 할 것인지 지정 
# Nvidia Tesla V100 (Cuda 11.0)
nvidia_accelerator_enabled: true 
nvidia_driver_version: "450.51.06" # gpu driver의 버전 정보 
nvidia_gpu_tesla_base_url: https://us.download.nvidia.com/tesla/
nvidia_gpu_gtx_base_url: http://us.download.nvidia.com/XFree86/Linux-x86_64/
nvidia_gpu_flavor: tesla
nvidia_url_end: "{{ nvidia_driver_version }}/NVIDIA-Linux-x86_64-{{ nvidia_driver_version }}.run"
nvidia_driver_install_container: true
nvidia_driver_install_centos_container: atzedevries/nvidia-centos-driver-installer:2
nvidia_driver_install_ubuntu_container: gcr.io/google-containers/ubuntu-nvidia-driver-installer@sha256:7df76a0f0a17294e86f691c81de6bbb7c04a1b4b3d4ea4e7e2cccdc42e1f6d63
nvidia_driver_install_supported: true
nvidia_gpu_device_plugin_container: "k8s.gcr.io/nvidia-gpu-device-plugin@sha256:0842734032018be107fa2490c98156992911e3e1f2a21e059ff0105b07dd8e9e"
# 위의 k8s-cluster.yml에서 지정한 것은 k8s taint를 설정하기 위한 용도임. (따라서 여기서도 지정해야 함)
nvidia_gpu_nodes: [node1] # gpu를 설치할 node name을 지정 (inventory.ini에 정의된 노드명)
nvidia_gpu_device_plugin_memory: 30Mi

```





## STEP 4. gpu가 정상적으로 설치되었는지 확인
#### Nvidia driver installer pod 동작 확인

```
> kubectl get pod -nkube-system
NAME                                       READY   STATUS    RESTARTS   AGE
nvidia-driver-installer-gnxzz              1/1     Running   0          19m
nvidia-gpu-device-plugin-94ccs             1/1     Running   0          19m

> kubectl logs -f nvidia-driver-installer-588gl -c nvidia-driver-installer -n kube-system
.... 
Running Nvidia installer... DONE.
Updated cached version as:
CACHE_KERNEL_VERSION=3.10.0-1160.2.2.el7.x86_64
CACHE_NVIDIA_DRIVER_VERSION=450.51.06
Verifying Nvidia installation...
Mon Nov 16 19:00:04 2020
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 450.51.06    Driver Version: 450.51.06    CUDA Version: 11.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  Tesla V100-PCIE...  Off  | 00000000:18:00.0 Off |                    0 |
| N/A   33C    P0    37W / 250W |      0MiB / 32510MiB |      0%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
Verifying Nvidia installation... DONE.
Updating host's ld cache...
Updating host's ld cache... DONE.
```
### Error 1
#### An NVIDIA kernel module 'nvidia' appears to already be loaded in your kernel. 
- kubectl log 로 확인해 보면 pod가 뜨면서, nvidia 프로세스가 이미 커널에 로딩되었다는 오류가 발생함. 
- kubernetes pod에서 nvidia 프로세스를 로딩해야 하는데, 이미 host에서 해당 프로세스를 로딩했다는 의미.
  - 그래서 시스템을 재 부팅해 보면, 자동으로 nvidia driver가 커널에 로딩되어 있음.
```
> kubectl logs nvidia-driver-installer-52pbt -c nvidia-driver-installer -nkube-system 
......
# 마지막에 이런 에러가 발생함. 
An NVIDIA kernel module 'nvidia' appears to already be loaded in your kernel.

# 1. nvidia module이 로드된 상태 확인 (kubernetes를 중지해도 host에서 자동으로 로딩함.)
> lsmod | grep nvidia
nvidia_drm             43690  0
nvidia_modeset       1091042  1 nvidia_drm
nvidia              18202459  1 nvidia_modeset
drm                   456166  5 ast,ttm,drm_kms_helper,nvidia_drm

```
#### Resolve
- 1. Host 서버에서 nvidia 드라이버를 삭제한다. 
```
> /usr/bin/nvidia-uninstall
```
- 2. cuda 드라이버를 삭제하고 재설치 
  - 이때 cuda driver만 설치하고, nvidia는 설치에서 제외한다. 
- 3. Host서버 재부팅 (아래와 같이 pod에 nvidia driver가 정상적으로 설치됨)
```
> kubectl logs -f nvidia-driver-installer-588gl -c nvidia-driver-installer -n kube-system
.... 
Running Nvidia installer... DONE.
Updated cached version as:
CACHE_KERNEL_VERSION=3.10.0-1160.2.2.el7.x86_64
CACHE_NVIDIA_DRIVER_VERSION=450.51.06
Verifying Nvidia installation...
Mon Nov 16 19:00:04 2020
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 450.51.06    Driver Version: 450.51.06    CUDA Version: 11.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  Tesla V100-PCIE...  Off  | 00000000:18:00.0 Off |                    0 |
| N/A   33C    P0    37W / 250W |      0MiB / 32510MiB |      0%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
Verifying Nvidia installation... DONE.
Updating host's ld cache...
Updating host's ld cache... DONE.
```


#### 최종 테스트 코드 
- https://github.com/NVIDIA/k8s-device-plugin/issues/165
- test.yml 
```
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod2
spec:
  restartPolicy: OnFailure
  tolerations:
    - key: "nvidia.com/gpu"  # type=specialnode 확인
      effect: "NoSchedule"
  containers:
    - name: cuda-container
      image: nvidia/cuda:10.2-base
      command: ["nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: 1 # requesting 1 GPU
```
- 결과 확인
```
> kubectl apply -f test.yml 
> kubectl describe pod gpu-pod2
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  11s   default-scheduler  Successfully assigned default/gpu-pod2 to node1
  Normal  Pulled     10s   kubelet, node1     Container image "nvidia/cuda:10.2-base" already present on machine
  Normal  Created    10s   kubelet, node1     Created container cuda-container
  Normal  Started    10s   kubelet, node1     Started container cuda-container
  
> kubectl logs gpu-pod2
Thu Jul 30 12:42:46 2020
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 450.51.06    Driver Version: 450.51.06    CUDA Version: 11.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  Tesla V100-SXM2...  Off  | 00000000:00:04.0 Off |                    0 |
| N/A   34C    P0    25W / 300W |      0MiB / 16160MiB |      0%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```


## K8s Node에 정상적으로 GPU 설정되었는지 확인
- https://cloud.google.com/kubernetes-engine/docs/how-to/gpus#multiple_gpus
- https://docs.nvidia.com/datacenter/kubernetes/kubernetes-upstream/index.html
```
> /usr/local/bin/kubectl describe nodes | grep -B 3 gpu
                    kubernetes.io/hostname=node1
                    kubernetes.io/os=linux
                    node-role.kubernetes.io/master=
                    nvidia.com/gpu=true
--
                    node.alpha.kubernetes.io/ttl: 0
                    volumes.kubernetes.io/controller-managed-attach-detach: true
CreationTimestamp:  Thu, 30 Jul 2020 12:12:28 +0000
Taints:             nvidia.com/gpu:NoSchedule
--
 hugepages-1Gi:      0
 hugepages-2Mi:      0
 memory:             30714472Ki
 nvidia.com/gpu:     1
--
 hugepages-1Gi:      0
 hugepages-2Mi:      0
 memory:             30112072Ki
 nvidia.com/gpu:     1
--
Non-terminated Pods:         (9 in total)
  Namespace                  Name                              CPU Requests  CPU Limits  Memory Requests  Memory Limits  AGE
  ---------                  ----                              ------------  ----------  ---------------  -------------  ---
  default                    gpu-pod                           0 (0%)        0 (0%)      0 (0%)           0 (0%)         67s
--
  kube-system                kube-scheduler-node1              100m (1%)     0 (0%)      0 (0%)           0 (0%)         19m
  kube-system                nodelocaldns-vk7kj                100m (1%)     0 (0%)      70Mi (0%)        170Mi (0%)     14m
  kube-system                nvidia-driver-installer-xc4bd     150m (1%)     0 (0%)      0 (0%)           0 (0%)         14m
  kube-system                nvidia-gpu-device-plugin-snq2p    50m (0%)      50m (0%)    30Mi (0%)        30Mi (0%)      14m
--
  cpu                1 (12%)         350m (4%)
  memory             168857600 (0%)  709715200 (2%)
  ephemeral-storage  0 (0%)          0 (0%)
  nvidia.com/gpu     1               1
```


#### delete taint for gpu
- taint를 삭제하여 cpu 기반의 작업도 해당 노드에서 실행할 수 있도록 변경한다. 
```
> kubectl taint nodes node1 nvidia.com/gpu-

> kubectl taint nodes node1 node.kubernetes.io/unschedulable-

> kubectl patch node node1 -p '{"spec":{"unschedulable":false}}'
```


## ETC 
### [참고] Ansible의 variable 정의 파일 및 적용 우선 순위
- 아래 방향으로 갈수록 우선순위가 높다  
- 즉, role default에 정의된 값은 위에서 정의된 변수가 덮어쓰게 된다. 
  - k8s-cluster.yml(inventory group_var/*)에서 정의하면,
  - nvidia_gpu/default/main.yml(role defaults)에 정의된 값을
  - 무시하고 덮어쓰게 된다. 
- https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable
```
command line values (eg “-u user”)
role defaults 
inventory file or script group vars 
inventory group_vars/all 
playbook group_vars/all
inventory group_vars/* 
playbook group_vars/* 
inventory file or script host vars 
inventory host_vars/* 
playbook host_vars/* 
host facts / cached set_facts 
play vars
play vars_prompt
play vars_files
role vars (defined in role/vars/main.yml)
block vars (only for tasks in block)
task vars (only for the task)
include_vars
set_facts / registered vars
role (and include_role) params
include params
extra vars (always win precedence)
```

https://github.com/NVIDIA/k8s-device-plugin