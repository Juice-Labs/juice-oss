# ![Logo](https://raw.githubusercontent.com/Juice-Labs/Juice-Labs/master/assets/Juice%4032px.png) Juice GPU-over-IP

[![Website](https://img.shields.io/static/v1.svg?color=F15722&labelColor=555555&logoColor=ffffff&style=for-the-badge&label=juicelabs.co&message=Website)](https://juicelabs.co)
[![Discord](https://img.shields.io/discord/755570806397993111.svg?color=F15722&labelColor=555555&logoColor=ffffff&style=for-the-badge&label=Discord&logo=discord)](https://discord.gg/xWHXNX8b3V)
[![Docs](https://img.shields.io/static/v1.svg?color=F15722&labelColor=555555&logoColor=ffffff&style=for-the-badge&label=Docs&logo=docsdotrs&message=Juice%20GPU)](https://juice-labs.github.io/juice-docs)

![Architecture](https://juice-labs.github.io/juice-docs/assets/images/JuiceComponents-e94534d8678bf77f611d131885d2cae1.png)

# What is Juice?

Juice is **GPU-over-IP**: client/server software that allows GPUs to be used over a standard TCP/IP network.  Run the Juice server on a machine with a physical GPU, and then immediately access that GPU from any machine with the Juice client software.

Client applications are unaware that the physical GPU is remote and **no modifications are necessary to application software**.  Juice client and server software runs equally well on **physical machines**, **VMs**, and **containers** on both **Linux** and **Windows**.  The only hard requirements are a GPU to serve and a network connection between the client and server.

# Why Juice?

GPU capacity is increasingly critical to major trends in computing, but its use is hampered by a major limitation: a GPU-hungry application can only run in the same physical machine as the GPU itself.  This limitation causes extreme local-resourcing problems -- there's either not enough (or none, depending on the size and power needs of the device), or GPU capacity sits idle and wasted (utilization is broadly estimated at below 15%).

**By abstracting application hosts from physical GPUs, Juice decouples GPU-consuming clients from GPU-providing servers:**

1. **Any client workload can access GPU from anywhere, creating new capabilities**
1. **GPU capacity is pooled and shared across wide areas -- GPU hardware scales independently of other computing resources**
1. **GPU utilization is driven much higher, and stranded capacity is rescued, by dynamically adding multiple clients to the same GPU based on resource needs and availability -- i.e. more workloads are served with the same GPU hardware**
