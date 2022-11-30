const util = require("util");
const request = util.promisify(require("request"));

task("getminerlist", "Start erc fils on the contract")
  .addParam("contract", "The address the staking contract")
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
    const networkId = network.name
    const stakingcon = await ethers.getContractFactory("StakingCon")

    //Get signer information
    const accounts = await ethers.getSigners()
    const signer = accounts[0]
    // const priorityFee = await callRpc("eth_maxPriorityFeePerGas")
    console.log("signer 0 is :",accounts[0].address)

    const stakingContract = new ethers.Contract(contractAddr, stakingcon.interface, signer)
    
    let result = await stakingContract.minePoolMap(1)
    console.log("minerlist result is: ", result.toString())
  })

module.exports = {}