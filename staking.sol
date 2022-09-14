// SPDX-License-Identifier: MIT
//https://github.com/andreitoma8/ERC20-Staking/blob/master/contracts/ERC20Stakeable.sol
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking_Contract is ERC20, ERC20Burnable, ReentrancyGuard {

//#################### State Variables ####################

    // Staker info
    struct Stakers_InFo {
        // The deposited tokens of the Staker
        uint256 deposited_Amount;
        // Last time of details update for Deposit
        uint256 timeOfLastUpdate;
        // Calculated, but unclaimed rewards. These are calculated each time
        // a user writes to the contract.
        uint256 unclaimedRewards;

    }

    // Rewards per hour. A fraction calculated as x/10.000.000 to get the percentage
    uint256 public rewardsPerHour = 200; // 0.00285%/h or 25% APR
    
    uint256 public stakers_amount = 0;
    uint256 public Unstakers_amount = 0;



    // Minimum amount to stake
    uint256 public minStake = 10 * 10**decimals();

    // Compounding frequency limit in seconds
    // uint256 public compoundFreq = 14400; //4 hours
       uint256 public compoundFreq = 14400;
    // Mapping of address to Staker info
    mapping(address => Stakers_InFo) public stakers_mapping;

// #################### Constructor ####################
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol){}

// #################### Functions ####################

//#################### 1st function deposit/staking ####################
       
       //1.if a particular address have no stakers InFo then initiate it
       //2.if a particular address already deposit/stake amount then calculate the rewards
       //  and add them to unclaimed rewards 
       //  Reset the time in {timeOfLastUpdate} and then add the amount to the already deposited 
       //  amount
       //3.Burns the Amount Staked from stakers address

function deposit(uint256 _amount)public nonReentrant {


      //entered amount is more than or equal to minimum stake
      require(_amount >= minStake,"you can only stake more than 10 tokens");
      //balance of sender/staker is greater than or equal to entered amount
      require((balanceOf(msg.sender) >= _amount),"you don't have enough balance to stake");
     
      if(stakers_mapping[msg.sender].deposited_Amount == 0){

         stakers_mapping[msg.sender].deposited_Amount = _amount;
         stakers_mapping[msg.sender].timeOfLastUpdate = block.timestamp;
         stakers_mapping[msg.sender].unclaimedRewards = 0;
         stakers_amount +=1;
      }
      else{
          
         uint256 rewards = calculateRewards(msg.sender);
         stakers_mapping[msg.sender].deposited_Amount += _amount;
         stakers_mapping[msg.sender].timeOfLastUpdate = block.timestamp;
         stakers_mapping[msg.sender].unclaimedRewards += rewards;
      }
      _burn(msg.sender,_amount);

}
//#################### 2nd function stakeRewards ####################
//by using this particular function stakers can able to stake theire rewards as well


function stakeRewards()public nonReentrant{
     require(stakers_mapping[msg.sender].deposited_Amount >= 0,"you need to stake first");
     require(compoundRewardsTimer(msg.sender) == 0,"Tried to compound rewards too soon");
     //get calculated rewards + rewards which they didn't withdraw 
      uint256 Rewards = calculateRewards(msg.sender) + stakers_mapping[msg.sender].unclaimedRewards;
      stakers_mapping[msg.sender].unclaimedRewards = 0;
      stakers_mapping[msg.sender].deposited_Amount += Rewards;
      stakers_mapping[msg.sender].timeOfLastUpdate = block.timestamp;
}

//#################### 3rd function Claim Rewards ####################
//this function takes address of staker and then add rewards to the rewards varibale which 
//calculate reward and unclaimed reward and after making changes in struct contract mints the tokens to the owners wallet
function ClaimRewards(address _stakers_address)public nonReentrant{
   uint256 rewards = calculateRewards(_stakers_address) + stakers_mapping[msg.sender].unclaimedRewards;
   require(rewards > 0,"you dont have any reward yet");
   stakers_mapping[_stakers_address].unclaimedRewards = 0;
   stakers_mapping[_stakers_address].timeOfLastUpdate = block.timestamp;
   _mint(_stakers_address,rewards);
}
//#################### 4th function withdraw entered amount #################### 
//you can withdraw any amount from your balanceat any time this function will subtract tokens
//from your mapping and then mint in your address
 function withdraw(uint _amount)public nonReentrant{
     require(_amount <= stakers_mapping[msg.sender].deposited_Amount,"you don't have enough balance");
     uint256 rewards = calculateRewards(msg.sender);
     stakers_mapping[msg.sender].deposited_Amount -= _amount;
     stakers_mapping[msg.sender].unclaimedRewards = rewards;
     stakers_mapping[msg.sender].timeOfLastUpdate = block.timestamp;
     _mint(msg.sender,_amount);
     Unstakers_amount +=1;
 }
 //#################### 5th function withdraw All amount #################### 
//here is the function where user can withdraw all his balance either it is reward or either it is
//his own staking tokens
 function withdrawAll() external nonReentrant {
        require(stakers_mapping[msg.sender].deposited_Amount > 0, "You have no deposit");
        uint256 _rewards = calculateRewards(msg.sender) +
            stakers_mapping[msg.sender].unclaimedRewards;
        uint256 _deposit = stakers_mapping[msg.sender].deposited_Amount;
        stakers_mapping[msg.sender].deposited_Amount = 0;
        stakers_mapping[msg.sender].timeOfLastUpdate = 0;
        uint256 _amount = _rewards + _deposit;
        _mint(msg.sender, _amount);
    }
 //#################### 6th functiont get info of staked amount and rewards amount ####################
 //by using this function user can get theire staked amount and also his rewards
 function getDepositInfo(address _user)public view returns(uint256,uint256){
     uint256 rewards = calculateRewards(_user) + stakers_mapping[_user].unclaimedRewards;
     uint256 balance = stakers_mapping[_user].deposited_Amount;
     return(rewards,balance);
 }
    //#################### 7th function compoundRewardsTimer ####################
    //in this particular function contract have if else statement
    //in if statement we check users time_of_last_updated + compound frequency which is 4 hours <= 
    //block.timestamp then it will return 0
    //otherwise it will return remining time to stake theire rewards as well 

    function compoundRewardsTimer(address _user)public view returns(uint256 _timer){
    
    if(stakers_mapping[_user].timeOfLastUpdate + compoundFreq <= block.timestamp){
        return 0;
    }
    else{
        return((stakers_mapping[_user].timeOfLastUpdate + compoundFreq)-block.timestamp);
    }
    }
    //#################### 8th function calculateRewards ####################
    //This function will calculate rewards it takes the address of staker and returns the reward 
    //after calculating reward 
    function calculateRewards(address _staker)
            public
            view
            returns (uint256 rewards)
        {
            return (((((block.timestamp - stakers_mapping[_staker].timeOfLastUpdate) *
                stakers_mapping[_staker].deposited_Amount) * rewardsPerHour) / 3600) / 10000000);
        }
    }
contract MyStakeableToken is Staking_Contract, Ownable {
    constructor(string memory _name, string memory _symbol)
        Staking_Contract(_name, _symbol)
    {
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    // Functions for modifying  staking mechanism variables:

    // Set rewards per hour as x/10.000.000 (Example: 100.000 = 1%)
    function setRewards(uint256 _rewardsPerHour) public onlyOwner {
        rewardsPerHour = _rewardsPerHour;
    }

    // Set the minimum amount for staking in wei
    function setMinStake(uint256 _minStake) public onlyOwner {
        minStake = _minStake;
    }

    // Set the minimum time that has to pass for a user to be able to restake rewards
    function setCompFreq(uint256 _compoundFreq) public onlyOwner {
        compoundFreq = _compoundFreq;
    }
}
