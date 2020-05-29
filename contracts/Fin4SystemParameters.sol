pragma solidity ^0.5.17;

contract Fin4SystemParameters {

    uint public REPforTokenCreation = 300;
    uint public REPforTokenClaim = 50;
    uint public REPforSuccesfulVote = 30;
    uint public REPforFailedVote = 30;

    function getSystemParameters() public view returns(uint, uint, uint, uint) {
        return (REPforTokenCreation, REPforTokenClaim, REPforSuccesfulVote, REPforFailedVote);
    }

}
