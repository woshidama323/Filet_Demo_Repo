## Introduction

Filet is a Filecoin mining power tokenization protocol that deployed on BSC , HECO  and FILECOIN(in the future,Just working on it on FEVM at the moment) network. It tokenizes Filecoin mining power and introduces it into the DeFi ecosystem to provide FIL holders with high-growth FIL staking services. 

Filet is backed by one of the largest storage providers in North America. The project is open source and audited by Certik. Currently over 210K FIL staked in Filet to join Filecoin mining. 

Webiste: www.filet.finance

Telegram: https://t.me/filet_finance

Twitter: https://twitter.com/Filet_finance

Email: contact@filet.finance


![image](https://user-images.githubusercontent.com/11014169/208602014-b3d46f35-3886-4b68-89a9-fa0b7bf2b8f3.png)

## Status

Now we are working on how to deploy and improve the feature on wallaby testnet

Will update the progress continually

Demo records link here:

https://docs.google.com/presentation/d/1H2a28a7f5aQR-nFSDtVeWesrbPSd-9Qq/edit?usp=sharing&ouid=102496921167907368420&rtpof=true&sd=true


## Goals

We want let smart contract act as miner actor and keep users' asset safe

## How to use it

### set env for specifying address private 
```shell
### export FILECOIN_Private= 
source .env
```

### deploy contract to specific netowrk 
```shell

###filecoinmaine /  calibration /  hyperspace
npx hardhat deploy --tags StakingCon --network hyperspace

```

### test with command below
```shell
npx hardhat test tests --network hyperspace
```


## TODO

### Improve
some test not pass with exit code 33 , will debug those issues

### design

1. How to make sure the users' asset safe if miner or SP not follow the rules and terminate sectors 

2. How to make sure the FILs safe if a hack issue happened for platform?
