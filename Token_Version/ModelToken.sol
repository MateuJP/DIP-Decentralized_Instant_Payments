// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.5.0/security/ReentrancyGuard.sol";

contract ModelContractToken is ReentrancyGuard {

    address public plataform;
    address public factory;
    address public manager;
    address payable public freelancer;
    address payable [] public referees ;
    address token_address;
    mapping (address => bool) has_voted_for_transfer;
    mapping (address => bool) has_voted_for_remove;
    mapping (address => bool) is_referee;
    mapping (address => bool) has_voted_for_unlock;
    uint256 public vote_transfer=0;
    uint256 public vote_retrieve=0;
    uint256 public vote_referee_transfer=0;
    uint256 public vote_referee_retrieve=0;
    uint256 public amountToRemove = 0;
    uint256 public total_budget; 
    uint256 immutable fee_plataform=3;
    uint256 public num_votes_refree=0;
    uint256 public votes_for_unlock=0;
    uint256 public num_votes_for_unlock=0;
    bool    public incident_retrieve=false;
    bool    public incident_transfer=false;
    bool    public is_valid;

    constructor (address _platform,address payable _freelancer, address payable[] memory _referees,address _manager,address _token,uint256 _budget){
        plataform=_platform;
        freelancer=_freelancer;
        referees=_referees;
        manager=_manager;
        token_address=_token;
        
        for(uint i=0;i<referees.length;i++){
            is_referee[referees[i]]=true;
        }
        total_budget=_budget;
        is_valid=true;
        factory=msg.sender;
    }
    modifier onlyFreelancer {
        require(msg.sender==freelancer);
        _;
    }

    modifier onlyManager {
        require(msg.sender==manager);
        _;
    }

    modifier onlyAuth{
        require(is_referee[msg.sender]||msg.sender==freelancer||msg.sender==manager);
        _;
    }

    modifier onlyActive{
        require(is_valid,"Smart contract is not valid");
        _;
    }

    event newIncident(address indexed project,address indexed initiator, uint256 typeIncident);
    event newRetrieveMoney(address indexed  project,address indexed to,uint256 amount);
    event newPayProject (address indexed project, address indexed to, uint256 amount);
    event newVote(address indexed project,address indexed addr_vote,uint256 vote);

   
    function sendTokens() public onlyActive onlyManager {
        IERC20 token = IERC20(token_address);
        require (token.balanceOf(msg.sender)>= total_budget, "You don't have enought Tokens");
        require(token.allowance(msg.sender,address(this))>= total_budget,"First Approve the smart contract to spend your Tokens");
        token.transferFrom(msg.sender,address(this),total_budget);
        setValid(true);
    }

    function increaseBadget(uint256 amount) public onlyActive onlyManager {
        IERC20 token = IERC20(token_address);
        require(token.balanceOf(msg.sender)>= amount,"You don't have enought Tokens");
        require(token.allowance(msg.sender,address(this))>= amount, "Please Approve the smart contract to spend your Tokens");
        token.transferFrom(msg.sender,address(this),amount);
        total_budget+=amount;
    }
    function viewBalanceSmartContract()public view returns(uint256){
        IERC20 token = IERC20(token_address);
        return token.balanceOf(address(this));
    }

    function setAmountToRemove(uint256 _amount) public onlyManager {
        require(_amount<=total_budget);
        amountToRemove=_amount;

    }

    function lockIncident(uint256 type_incident) public onlyActive{
        require(!incident_retrieve && !incident_transfer,"There's an incident right now");
        require(msg.sender==freelancer || msg.sender==manager,"You are not allowed");
        require(type_incident==0 || type_incident==1);
        if(type_incident==0){
            incident_retrieve=true;
            vote_referee_transfer=0;
            vote_transfer=0;
        }else{
            incident_transfer=true;
            vote_referee_retrieve=0;
            vote_retrieve=0;
        }
        emit newIncident(address(this),msg.sender,type_incident);    
    }
    function unlockIncident(uint256 vote) public onlyActive nonReentrant{
        require(msg.sender==freelancer || msg.sender==manager,"You are not allowed");
        require(vote==0 || vote==1);
        require(!has_voted_for_unlock[msg.sender],"You just can vote once");
        votes_for_unlock+=vote;
        num_votes_for_unlock++;
        has_voted_for_unlock[msg.sender]=true;
        
        if(votes_for_unlock==2){
            has_voted_for_unlock[freelancer]=false;
            has_voted_for_unlock[manager]=false;
            num_votes_for_unlock=0;
            votes_for_unlock=0;
            if(incident_retrieve==true && !(vote_referee_retrieve>=2 && num_votes_refree <=4)){
            incident_retrieve=false;
            resetMapping(0);
            vote_retrieve=0;
            vote_referee_retrieve=0;
            num_votes_refree=0;
            }else if(incident_transfer==true && !(vote_referee_transfer>=2 && num_votes_refree<=4)){
                incident_transfer=false;
                resetMapping(1);
                vote_transfer=0;
                vote_referee_transfer=0;
                num_votes_refree=0;
            }else{
                revert("There's no incident to unlock");
            }
        }else if(num_votes_for_unlock==2){
            votes_for_unlock=0;
            has_voted_for_unlock[freelancer]=false;
            has_voted_for_unlock[manager]=false;
            num_votes_for_unlock=0;

        }   
    }


    function setValid(bool value) internal {
        is_valid=value;
    }
    function resetMapping(uint256 map) internal {
        if(map==0){
            for(uint i=0;i<referees.length;i++){
                has_voted_for_remove[referees[i]]=false;
            }
            has_voted_for_remove[freelancer]=false;
            has_voted_for_remove[manager]=false;
        }else{
            for(uint i=0;i<referees.length;i++){
                has_voted_for_transfer[referees[i]]=false;
            }
            has_voted_for_transfer[freelancer]=false;
            has_voted_for_transfer[manager]=false;
        }
        
    }
    function retriveTokens(uint256 vote) public onlyActive onlyAuth nonReentrant{ 
        require(amountToRemove>0, "There is no money for retrieve");
        require(vote_referee_transfer==0 && vote_transfer==0);
        require(!incident_transfer,"You can't remove money while an incident regarding to transfer is on");
        require(vote==0 || vote==1);
        require(!has_voted_for_remove[msg.sender],"You can't vote more than once");
        
        if(!is_referee[msg.sender]){
            vote_retrieve+=vote;
            has_voted_for_remove[msg.sender]=true;
            if(vote==0 && !incident_retrieve){
                incident_retrieve=true;   
                emit newIncident(address(this),msg.sender,0);
            }
        }else{
            require(incident_retrieve, "Your vote is not necessary");
            num_votes_refree++;
            vote_referee_retrieve+=vote;
            has_voted_for_remove[msg.sender]=true;
            if(vote==0 && (num_votes_refree>4 && vote_referee_retrieve<3)){
                resetMapping(0);
                num_votes_refree=0;
                vote_referee_retrieve=0;
                vote_retrieve=0;
                incident_retrieve=false;
            }
        }

        if(vote_retrieve==2 || vote_referee_retrieve>=3){
            IERC20 token = IERC20(token_address);
            token.transferFrom(address(this),manager,amountToRemove);
            total_budget-=amountToRemove;
            amountToRemove=0;
            vote_referee_retrieve=0;
            vote_retrieve=0;
            incident_retrieve=false;
            resetMapping(0);
            emit newRetrieveMoney(address(this),manager,amountToRemove);
        }else{
            emit newVote(address(this),msg.sender,vote);
        }
        
    }
  
    function transferMoney(uint256 vote) public onlyActive onlyAuth nonReentrant {
        require(vote_referee_retrieve==0 && vote_retrieve==0);
        require(!incident_retrieve,"You can't transfer the money while a incident regrding to retrive money is on");
        require(vote==0 || vote==1);
        require(!has_voted_for_transfer[msg.sender],"You can't vote more than once");
        
        if(!is_referee[msg.sender]){
            vote_transfer+=vote;
            if(vote==0 && !incident_transfer){
                incident_transfer=true;
                emit newIncident(address(this),msg.sender,1);
            }
            has_voted_for_transfer[msg.sender]=true;
        }else{
            require(incident_transfer, "Your vote is not necessary" );
            vote_referee_transfer+=vote;
            num_votes_refree++;
            has_voted_for_transfer[msg.sender]=true;
            if(vote==0 && (num_votes_refree>4 && vote_referee_transfer<3) ){
                resetMapping(0);
                num_votes_refree=0;
                vote_referee_transfer=0;
                vote_transfer=0;
                incident_transfer=false;
            }

        }
        if(vote_transfer==2 || vote_referee_transfer>=3){
            vote_referee_transfer=0;
            vote_transfer=0;
            IERC20 token = IERC20(token_address);
            uint256 to_plataform = (total_budget * fee_plataform) / 100;
            uint256 to_freelancer = total_budget - to_plataform;
            token.transferFrom(address(this),plataform,to_plataform);
            token.transferFrom(address(this),manager,to_freelancer);
            total_budget=0;
            incident_transfer=false;
            resetMapping(1);
            setValid(false);
            emit newPayProject(address(this),freelancer,to_freelancer);
        }else{
            emit newVote(address(this),msg.sender,vote);
        }
        
    }

    function changeReferee(address oldReferee, address newReferee) external nonReentrant {
        require(msg.sender==factory,"You are not allowed");
        is_referee[oldReferee]=false;
        is_referee[newReferee]=true;
        for(uint i=0;i<referees.length;i++){
            if(referees[i]==oldReferee){
                referees[i]=payable(newReferee);
            }
        }
    }
}