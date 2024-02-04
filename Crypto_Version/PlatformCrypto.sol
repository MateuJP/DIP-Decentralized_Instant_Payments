// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.5.0/security/ReentrancyGuard.sol";
import "./FactoryCrypto.sol";

contract PlatformManagmentCrypto is ReentrancyGuard {
    address     payable public owner;
    address     payable []  public reefrees;
    address     public addr_factory;
    address     [] public managers;
    uint256     public fee_platform;
    uint256     public fee_reefrees;
    uint256     public fee_referee;
    uint256     public total_refrees;
    uint256     public current_refree=0;
    mapping     (address=> bool) is_active;
    mapping     (address => bool) is_manager;
    mapping     (address => uint256) token_amount;
    
    constructor(){
        owner=payable(msg.sender);
        fee_platform=30;
        fee_reefrees=70;
        fee_referee=5;
    }

    modifier onlyOwner {
        require(msg.sender==owner,"You are not the owner of the Smart Contract");
        _;
    }

    modifier onlyManagers {
        require(is_manager[msg.sender], "You do not have permission to create a new project.");
        _;
    }

    event newReferee(address indexed project,address indexed oldReferee,address indexed _newReferee);
    event newPayment(uint256 amount_to_platform,uint256 amount_to_referee);

    
    function changeOwner(address payable _newOwner) public onlyOwner {
        owner=_newOwner;
    }
    
    function addFactory(address _factroy) public onlyOwner {
        addr_factory=_factroy;
    }

    function addReefree(address payable _refree) public {
        reefrees.push(_refree);
        is_active[_refree]=false;
        total_refrees++;
    }

    function addManager(address _manager) public onlyOwner {
        managers.push(_manager);
        is_manager[_manager]=true;
    }

    function removeReefree(address _reefree) public onlyOwner {
        is_active[_reefree]=false;
    }

    function createProject(address payable _freelancer,address payable [] memory _reefrees, uint256 _totalBudget) public onlyManagers returns(address){
        require(addr_factory != address(0x0));
        FactoryContractCrypto factory=FactoryContractCrypto(addr_factory);
        address addr_cont =factory.createProjectCrypto(_freelancer,payable(msg.sender),_reefrees,_totalBudget);
        
        for(uint i=0;i<_reefrees.length;i++){
            if(!is_active[_reefrees[i]]){
                is_active[_reefrees[i]]=true;
            }
        }
        return addr_cont;

    }

    function reciveCyptos() external payable nonReentrant {
        
    }
    
    function distributeTokens() public onlyOwner nonReentrant {

        uint256 total_balance = address(this).balance;
        require(total_balance > 0, "There are no funds to distribute.");
        // Amount to the referees
        uint256 total_amount_to_refree = (total_balance * fee_reefrees) / 100;
        // Amount to the plataform
        uint256 amount_to_platform = (total_balance * fee_platform) / 100;
        // Amount to single reefere
        uint256 amount_to_reefree = (total_amount_to_refree * fee_referee)/100;
        while(total_amount_to_refree>0){
            address payable refree = reefrees[current_refree % total_refrees];
            if(is_active[refree]){
                refree.transfer(amount_to_reefree);
                total_amount_to_refree-=amount_to_reefree;
            }
            current_refree += 1;
        }
        owner.transfer(amount_to_platform);
        emit newPayment(amount_to_platform,amount_to_reefree);
    }
    function changeReferee(address oldReferee,address _newReferee,address project) public onlyOwner{
        FactoryContractCrypto factory=FactoryContractCrypto(addr_factory);
        factory.changeRefeere(oldReferee,_newReferee,project);
        if(!is_active[_newReferee]){
            is_active[_newReferee]=true;
        }
        is_active[oldReferee]=false;
        emit newReferee(project,oldReferee,_newReferee);

    }



}
