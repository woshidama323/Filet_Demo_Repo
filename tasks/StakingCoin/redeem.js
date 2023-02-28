const util = require("util");
const request = util.promisify(require("request"));

task("redeem", "Start staking fils on the contract")
  .addParam("contractaddress", "The address the staking contract")
  .addParam("orderid", "The address of the account you want the balance for")
  .addParam("amount", "The address of the account you want the balance for")
  .addParam("someone", "The address of the account you want the balance for")
  .setAction(async (taskArgs) => {
    
    async function callRpc(method, params) {
      var options = {
        method: "POST",
        url: network.config.url,
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          jsonrpc: "2.0",
          method: method,
          params: params,
          id: 1,
        }),
      };
      const res = await request(options);
      return JSON.parse(res.body).result;
    }

    const contractAddr = taskArgs.contractaddress
    const amount = taskArgs.amount
    const orderID = taskArgs.orderid
    const someone = taskArgs.someone
    const networkId = network.name
    // console.log("Reading StakingCon owned by", account, " on network ", networkId)
    const StakingCon = await ethers.getContractFactory("StakingCon")

    //Get signer information
    const accounts = await ethers.getSigners()
    const signer = accounts[0]
    const priorityFee = await callRpc("eth_maxPriorityFeePerGas")
    console.log("signer0 is :",accounts[0].address)
    // console.log("signer1 is :",accounts[1].address)

    const stakingContract = new ethers.Contract(contractAddr, StakingCon.interface, signer)
    //start staking contract 
    
    let result = await stakingContract.redeem(orderID,amount,someone, {
        gasLimit: 1000000000,
        maxPriorityFeePerGas: priorityFee
    })
    console.log("staking result is: ", result)
  })

module.exports = {}