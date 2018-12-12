# XenDesktop-AddComputer
使用Citrix XenDesktop MCS 模式自动发布桌面
默认交互组名与桌面Hostname一致，一台桌面一个交互组，方便二次开发重新分配桌面，有利于实现单点登录
执行脚本需要三个参数，分别是计算机目录名（计算机目录含有MCS的黄金镜像、计算机命令规则、初始桌面硬件规格以及网络存储配置）、交互组列表（"xx,yy,sss,dddd,zz"）、用户列表（"user1,user2,user3,user4"）
交互组列表以及用户列表长度应一致
脚本会通过交互组的长度判断需要发布的桌面个数
