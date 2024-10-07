# GPU SLICING

Time-slicing, in the context of GPU sharing on platforms like Amazon EKS, refers to the method where multiple tasks or processes share the GPU resources in small time intervals, ensuring efficient utilization and task concurrency.\
GPU time-slicing in Kubernetes allows tasks to share a GPU by taking turns. This is especially useful when the GPU is oversubscribed. System administrators can create “replicas” for a GPU, with each replica designated to a specific task or pod. However, these replicas don’t offer separate memory or fault protection. When applications on EC2 instances don’t fully utilize the GPU, the time-slicing scheduler can be employed to optimize resource use. By default, Kubernetes allocates a whole GPU to a pod, often leading to underutilization. Time-slicing ensures that multiple pods can efficiently share a single GPU, making it a valuable strategy for varied Kubernetes workloads

## Scenarios and workloads for time-slicing
1. Multiple small-scale workloads: 

- For organizations running multiple small-to medium-sized workloads simultaneously, time-slicing ensures that each workload gets a fair share of the GPU, maximizing throughput without the need for multiple dedicated GPUs.
  
2. Development and testing environments: 

- In scenarios where developers and data scientists are prototyping, testing, or debugging models, they might not need continuous GPU access. Time-slicing allows multiple users to share GPU resources efficiently during these intermittent usage patterns.

3. Batch processing: 

- For workloads that involve processing large datasets in batches, time-slicing can ensure that each batch gets dedicated GPU time, leading to consistent and efficient processing.

4. Real-time analytics:

- In environments where real-time data analytics is crucial, and data arrives in streams, time-slicing ensures that the GPU can process multiple data streams concurrently, delivering real-time insights.
5. Simulations:

- For industries like finance or healthcare, where simulations are run periodically but not continuously, time-slicing can allocate GPU resources to these tasks when needed, ensuring timely completion without resource waste.

6. Hybrid workloads:

- In scenarios where an organization runs a mix of AI, ML, and traditional computational tasks, time-slicing can dynamically allocate GPU resources based on the immediate demand of each task.

7. Cost efficiency: 

- For startups or small-and medium-sized enterprises with budget constraints, investing in a fleet of GPUs might not be feasible. Time-slicing allows them to maximize the utility of limited GPU resources, catering to multiple users or tasks without compromising performance.

## Implementation
To enable GPU slicing on Amazon EKS and optimize costs for GPU-intensive workloads, you can implement GPU time-slicing with the NVIDIA device plugin. Here’s how you can set it up and integrate it with Karpenter, if it’s used for auto-scaling:

### Configuring GPU Slicing on EKS
1. Remove the Existing NVIDIA Device Plugin: If you already have an existing NVIDIA device plugin, remove it to avoid conflicts:
```
kubectl delete daemonset nvidia-device-plugin-daemonset -n kube-system
```
2. Create a ConfigMap for Time-Slicing: Define a ConfigMap that specifies how to slice the GPU. For example, if a single GPU can be split into 10 slices, use the following configuration:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: time-slicing-config-all
data:
  any: |-
    version: v1
    flags:
      migStrategy: none
    sharing:
      timeSlicing:
        resources:
        - name: nvidia.com/gpu
          replicas: 10
```
Apply this configuration to the cluster:
```
kubectl create -n kube-system -f time-slicing-config-all.yaml
```
3. Deploy the NVIDIA Device Plugin with the ConfigMap: Install the NVIDIA device plugin using Helm, referencing the ConfigMap created:
```
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --version=0.14.1 \
  --namespace kube-system \
  --create-namespace \
  --set config.name=time-slicing-config-all
```
After deployment, the cluster nodes should reflect the GPU slices as separate resources (e.g., a single GPU with 10 slices would show as `nvidia.com/gpu: 10`)​
### Enabling GPU Slicing with Karpenter Autoscaler:
Karpenter can be configured to support bin-packing and GPU optimization with GPU slicing by adjusting its provisioner specifications.
1. Create or Update a Karpenter Provisioner: To enable effective resource utilization and bin-packing of sliced GPUs, use the following configuration example for Karpenter:
```
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: gpu-slicing-provisioner
spec:
  consolidation:
    enabled: true
  requirements:
    - key: "nvidia.com/gpu"
      operator: In
      values: ["1"]  # Adjust based on the number of slices needed
  provider:
    instanceType: g4dn.xlarge  # Or other GPU-supported instance types
    architecture: x86_64
```
2. Additional Configuration for Managing GPU Utilization:
- Enable the consolidation flag within the Karpenter provisioner to allow efficient packing of pods onto GPU slices.
- Ensure the maxPods setting is adjusted based on the number of slices and pods per GPU.

3. Integrate with Existing Clusters: For clusters already using Karpenter, you can apply these configurations to update the current provisioners. Make sure that each provisioner handles the appropriate GPU instances and has the consolidation flag set to optimize node utilization​(AWS Open Source).

## Considerations for AI Workloads:
- Compatibility: Ensure that your AI frameworks (e.g., TensorFlow, PyTorch) are compatible with GPU slicing. Some frameworks may require specific flags or environment variables to work correctly with fractional GPUs.

- Performance Tuning: For time-sliced GPUs, there can be some performance trade-offs. If a single AI job needs low latency, consider using a full MIG slice instead of a time-sliced partition.

- Pod Scheduling Constraints: Use taints, tolerations, and node selectors to ensure that AI workloads only land on nodes with GPU slicing enabled.

By implementing GPU slicing in EKS, your AI workloads can achieve higher utilization and cost efficiency while retaining the flexibility and scalability benefits of the Kubernetes ecosystem​

## PROS/CONS
### Pros
1. Improved resource utilization: 
- GPU sharing allows for better utilization of GPU resources by enabling multiple pods to use the same GPU. This means that even smaller workloads that don’t require the full power of a GPU can still benefit from GPU acceleration without wasting resources.
  
2. Cost optimization: 
- GPU sharing can help reduce costs by improving resource utilization. With GPU sharing, you can run more workloads on the same number of GPUs, effectively spreading the cost of those GPUs across more workloads.

3. Increased throughput: 
- GPU sharing enhances the system’s overall throughput by enabling multiple workloads to operate at once. This is especially advantageous during periods of intense demand or high load situations, where there’s a surge in the number of simultaneous requests. By addressing more requests within the same timeframe, the system achieves improved resource utilization, leading to optimized performance.

4. Flexibility: 
- Time-slicing can accommodate a variety of workloads, from machine learning tasks to graphics rendering, allowing diverse applications to share the same GPU.

5. Compatibility: 
- Time-slicing can be beneficial for older generation GPUs that don’t support other sharing mechanisms like MIG.

### Cons
1. No memory or fault isolation:
- Unlike mechanisms like MIG, time-slicing doesn’t provide memory or fault isolation between tasks. If one task crashes or misbehaves, it can affect others sharing the GPU.

2. Potential latency: 
- As tasks take turns using the GPU, there might be slight delays, which could impact real-time or latency-sensitive applications.

3. Complex resource management: 
- Ensuring fair and efficient distribution of GPU resources among multiple tasks can be challenging. 

4. Overhead: 
- The process of switching between tasks can introduce overhead in terms of computational time and resources, especially if the switching frequency is high. This can potentially lead to reduced overall performance for the tasks being executed.

5. Potential for starvation:
- Without proper management, some tasks might get more GPU time than others, leading to resource starvation for less prioritized tasks.


## Conclusion
Using GPU sharing on Amazon EKS, with the help of NVIDIA’s time-slicing and accelerated EC2 instances, changes how companies use GPU resources in the cloud. This method saves money and boosts system speed, helping with many different tasks. There are some challenges with GPU sharing, like making sure each task gets its fair share of the GPU. But the big benefits show why it’s a key part of modern Kubernetes setups. Whether it’s for machine learning or detailed graphics, GPU sharing on Amazon EKS helps users get the most from their GPUs. 

## Documents
[https://aws.amazon.com/blogs/containers/gpu-sharing-on-amazon-eks-with-nvidia-time-slicing-and-accelerated-ec2-instances/]
[https://aws.amazon.com/blogs/containers/delivering-video-content-with-fractional-gpus-in-containers-on-amazon-eks/]
[https://aws.github.io/aws-eks-best-practices/cost_optimization/cost_opt_compute/]