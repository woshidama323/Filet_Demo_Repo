const util = require("util");
const request = util.promisify(require("request"));

task("erctest", "Start erc fils on the contract")
  .addParam("contract", "The address the staking contract")
  .addParam("account", "The address of the account you want the balance for")
  .setAction(async (taskArgs) => {
    
    async function callRpc(method, params) {
      var options = {
        method: "POST",
        url: "https://wallaby.node.glif.io/rpc/v0",
        // url: "http://localhost:1234/rpc/v0",
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

    const contractAddr = taskArgs.contract
    const account = taskArgs.account
    const networkId = network.name
    console.log("Reading ERC20Token owned by", account, " on network ", networkId)
    const ERC20Token = await ethers.getContractFactory("ERC20Token")

    //Get signer information
    const accounts = await ethers.getSigners()
    const signer = accounts[0]
    const priorityFee = await callRpc("eth_maxPriorityFeePerGas")
    console.log("signer 0 is :",accounts[0].address)
    console.log("signer 1 is :",accounts[1].address)

    const ERC20TokenContract = new ethers.Contract(contractAddr, ERC20Token.interface, signer)
    
    //start staking contract 

    let transferresult = await ERC20TokenContract.transfer(accounts[1].address,"1000", {
        gasLimit: 1000000000,
        maxPriorityFeePerGas: priorityFee
    })
    console.log("transferresult result is: ", transferresult)
    
    let result = await ERC20TokenContract.balanceOf(accounts[1].address)
    console.log("balanceOf result is: ", result.tostring())
  })

module.exports = {}