# RTL开发环节
## 主要目标
完成axi2axi stream bridge的开发

## 功能描述
axi4接口用于接受axi master的访问，cq接口用于完成 write/read的请求，以及write data的发送，cc接口用于完成 write resp和read data的响应
Axi的sideband信号指示了pcie相关的传输字段，具体含义可以查看signal descrip里的描述，cq和cc接口的报文结构咋operation_describ目录下

## 要求
全部采用可综合verilog编写

顶层已经在rtl下给出，不要修改顶层的参数和port

有不确定的地方，不要自己幻想


## 编写代码前需要做的事

首先制定开发的架构，并且向我确认

只修改你需要修改的部分

确认好架构后，写下spec，并且向我确认你已经理解了我的需求

写代码的要求放在Agent.md中

## 提示

读文件只在你有需求的时候读取你需要的部分

所有的信号可以参考signal describe目录下的文件

axi stream的传递行为在operation_describe下的axi_stream_complete.md

# 验证环节
此环节是在RTL开发环节结束后，由用户确定后方才开启的环节

## 主要目标
根据设计的spec开发验证平台，并且执行仿真验证

## 验证步骤
1.制定验证计划
2.编写验证平台
3.创建测试用例并仿真

## 要求
1.验证计划和测试点写入验证spec中，供用户审核查阅
2.验证平台全部写在./tb目录下，采用System verilog编写
3.执行仿真需要dump波形，并且将transaction记录在log中，记录的为一笔有效握手下的axi transaction和axi stream transaction。axi transaction要求将有必要的sideband信号都记录下来，并且说明字段代表的pcie报文含义。axi stream transaction记录时，需要解析报文内容，确认此笔传输是descripter还是pload，是descripter的话，需要描述descripter代表了什么样的pcie报文
4.仿真过程如果发现rtl的bug可以修改，但是在修改前需要确认旧版本已经传入git仓库
5.所有的仿真临时文件放在tmp目录下
6.执行仿真的过程，要求地址和数据是随机的，并且一条case应当多跑几个transaction来避免偶然性


## 工具
所有需要的工具都放在oss-cad-suite里
git工具在portablegit下
