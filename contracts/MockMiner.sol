import {MinerAPI} from "./MinerAPI.sol";
import {CommonTypes} from "./types/CommonTypes.sol";
import {MinerTypes} from "./types/MinerTypes.sol";

contract MockMiner is MinerAPI{
    constructor() MinerAPI("test") {
    }
}