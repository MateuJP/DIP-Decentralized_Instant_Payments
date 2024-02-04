// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ModelToken.sol";

contract FactoryContractStableCoin {
    address public owner;
    address public platform;     

    constructor(address _platfrom){
        owner=msg.sender;
        platform=_platfrom;
    }

    modifier onlyOwner {
        require(msg.sender==owner,"You are not the owner of the Smart Contract");
        _;
    }
    modifier onlyPlatform {
        require(msg.sender==platform,"You are not the owner of the Smart Contract");
        _;
    }

    event newProject(address indexed newContract,address indexed manager, uint256 total_budget);
    
    function changeOwner(address _newOwner) public onlyOwner {
        owner=_newOwner;
    }
    function changePlatform(address _newPlatfrom) public onlyOwner {
        platform=_newPlatfrom;
    }

    function createProjectToken(address payable freelancer,address payable [] memory _referees,address manager ,address token,uint256 totalBudget) external onlyPlatform returns (address) {
        address addr_mt= address(new ModelContractToken(platform,freelancer,_referees,manager,token,totalBudget));
        emit newProject(addr_mt,manager,totalBudget);
        return addr_mt;
    }

     function changeRefeere(address oldReferee, address newReferee,address Project) external onlyPlatform {
        ModelContractToken mt=ModelContractToken(Project);
        mt.changeReferee(oldReferee,newReferee);
    }


}
