pragma solidity ^0.5.0;

import "contracts/proof/Fin4BaseProofType.sol";

contract MaximumQuantityPerInterval is Fin4BaseProofType {

  constructor(address Fin4MessagingAddress)
    Fin4BaseProofType(Fin4MessagingAddress)
    public {
      name = "MaximumQuantityPerInterval";
      description = "Defines the maximum quantity a user can claim within a specified time interval.";
      // interval = 1 * 24 * 60 * 60 * 1000; // 1 day
      // maxQuantity = 10;
    }

    function submitProof_MaximumQuantityPerInterval(address tokenAddrToReceiveProof, uint claimId) public {
      if (requirementMet(tokenAddrToReceiveProof, msg.sender, claimId)) {
        _sendApproval(address(this), tokenAddrToReceiveProof, claimId);
      } else {
        string memory message = string(abi.encodePacked(
          Fin4TokenStub(tokenAddrToReceiveProof).name(),
          ": The quantity you are claiming would take you beyond the allowed amount for the given interval. Interval: ",
          uint2str(_getInterval(tokenAddrToReceiveProof) / 1000), "s, max. quantity: ",
          uint2str(_getMaxQuantity(tokenAddrToReceiveProof)), "."
        ));
        Fin4Messaging(Fin4MessagingAddress).addInfoMessage(address(this), msg.sender, message);
        _sendRejection(address(this), tokenAddrToReceiveProof, claimId);
      }
    }

    function requirementMet(address tokenAddressUsingThisProofType, address claimer, uint claimId) private view returns(bool) {
      uint sum;
      uint requestedQuantity;
      (sum, requestedQuantity) = Fin4TokenStub(tokenAddressUsingThisProofType)
        .sumUpQuantitiesWithinIntervalBeforeThisClaim(claimer, claimId, _getInterval(tokenAddressUsingThisProofType));
      return sum + requestedQuantity <= _getMaxQuantity(tokenAddressUsingThisProofType);
    }

    // @Override
    function getParameterForTokenCreatorToSetEncoded() public pure returns(string memory) {
      return "uint:interval:days,uint:maxQuantity:quantity";
    }

    mapping (address => uint[]) public tokenToParameters;

    function setParameters(address token, uint interval, uint maxQuantity) public {
      tokenToParameters[token] = [interval, maxQuantity];
    }

    /*
    function getParameterizedDescription(address token) public view returns(string memory) {
      return string(abi.encodePacked(
          "The token creator defined a maximum quantity of ",
          uint2str(_getMaxQuantity(token)),
          " to be claimable in an interval of ",
          uint2str(_getInterval(token) / (1000 * 60 * 60 * 24)), " days."
        ));
    }*/

    function _getInterval(address token) private view returns(uint) {
      return tokenToParameters[token][0] * 24 * 60 * 60 * 1000; // from days to miliseconds
    }

    function _getMaxQuantity(address token) private view returns(uint) {
      return tokenToParameters[token][1];
    }
}
