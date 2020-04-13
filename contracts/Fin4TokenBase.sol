pragma solidity ^0.5.0;

import 'contracts/Fin4Proving.sol';
import "contracts/proof/Fin4BaseProofType.sol";
import "contracts/stub/Fin4ClaimingStub.sol";

contract Fin4TokenBase { // abstract class

  address public Fin4ClaimingAddress;
  address public Fin4ProvingAddress;
  address public tokenCreator;
  string public description;
  string public actionsText;
  string public unit;
  uint public tokenCreationTime;
  uint public fixedAmount;
  uint public initialSupply;

  bool private initDone = false;
  bool private Fin4ClaimingHasMinterRole = true;

  // TODO instead of keeping copies here, instead just store indizes
  // of the array in Fin4TokenManagement?
  bytes32[] public mechanisms;

  constructor() public {
    tokenCreationTime = now;
  }

  function init(address Fin4ClaimingAddr, bool _Fin4ClaimingHasMinterRole, string memory _description, string memory _actionsText,
    uint _fixedAmount, string memory _unit) public {
    require(!initDone, "init() can only be called once"); // TODO also require token creator?
    Fin4ClaimingAddress = Fin4ClaimingAddr;
    Fin4ClaimingHasMinterRole = _Fin4ClaimingHasMinterRole;
    description = _description;
    actionsText = _actionsText;
    fixedAmount = _fixedAmount;
    unit = _unit;
    initDone = true;
  }

  function setMechanismsOnToken(bytes32[] memory _mechanisms) public {
    mechanisms = _mechanisms;
  }

  function getMechanismsOnToken() public view returns(bytes32[] memory) {
    return mechanisms;
  }

  function name() public view returns(string memory);
  function symbol() public view returns(string memory);

  // ------------------------- CLAIM -------------------------

  uint nextClaimId = 0;

	struct Claim {
    uint claimId;
    address claimer;
    bool isApproved;
    uint quantity;
    // uint timeGivenByUser; // TODO if useful? #ConceptualDecision
    string comment;
    address[] requiredProofTypes;
    mapping(address => bool) proofStatuses;
    mapping(address => uint) proofInteractionTimes;
    uint claimCreationTime;
    uint claimApprovalTime;
    bool gotRejected;
    address[] rejectedByProofTypes;
  }

	mapping (uint => Claim) public claims;

  // intentional forwarding like this so that the front end doesn't need to know which token to submit a claim to at the moment of submitting it
	function submitClaim(address claimer, uint variableAmount, string memory comment) public returns (uint, address[] memory, uint, uint) {
    require(initDone, "Token is not initialized");
    Claim storage claim = claims[nextClaimId];
    claim.claimCreationTime = now;
    claim.claimId = nextClaimId;
    claim.claimer = claimer;

    // a require() in Fin4TokenManagement.createNewToken() made sure they are not both zero or nonzero

    if (fixedAmount == 0) {
      claim.quantity = variableAmount;
    } else {
      claim.quantity = fixedAmount;
    }

    claim.comment = comment;
    // make a deep copy because the token creator might change the required proof types, but throughout the lifecycle of a claim they should stay fix
    // TODO should they? --> #ConceptualDecision
    claim.requiredProofTypes = getRequiredProofTypes();
    // initialize all the proofs required by the token creator with false
    // TODO isn't the default initialization false?
    for (uint i = 0; i < claim.requiredProofTypes.length; i ++) {
      claim.proofStatuses[claim.requiredProofTypes[i]] = false;
    }
    claim.isApproved = false;
    claim.gotRejected = false;

    if (claim.requiredProofTypes.length == 0) {
      approveClaim(nextClaimId);
    }

    nextClaimId ++;
    return (nextClaimId - 1, claim.requiredProofTypes, claim.claimCreationTime, claim.quantity);
  }

  function getClaim(uint claimId) public view returns(address, bool, bool, uint, uint, string memory, address[] memory, bool[] memory) {
    // require(claims[claimId].claimer == msg.sender, "This claim was not submitted by the sender");

    Claim storage claim = claims[claimId];
    // This assumes the proof types are still the same as when the claim was submitted
    // We probably want to support an evolving set of proof types though? TODO
    address[] memory requiredProofTypes = getRequiredProofTypes();
    bool[] memory proofTypeStatuses = new bool[](requiredProofTypes.length);
    for (uint i = 0; i < requiredProofTypes.length; i ++) {
      proofTypeStatuses[i] = claim.proofStatuses[requiredProofTypes[i]];
    }

    return (claim.claimer, claim.isApproved, claim.gotRejected, claim.quantity, claim.claimCreationTime,
      claim.comment, requiredProofTypes, proofTypeStatuses);
  }

  function getClaimInfo(uint claimId) public view returns(address, bool, uint, uint, string memory) {
    return (claims[claimId].claimer, claims[claimId].isApproved,
      claims[claimId].quantity, claims[claimId].claimCreationTime, claims[claimId].comment);
  }

  function getClaimIds(address claimer) public view returns(uint[] memory) {
    uint count = 0;
    for (uint i = 0; i < nextClaimId; i ++) {
      if (claims[i].claimer == claimer) {
          count ++;
      }
    }
    uint[] memory ids = new uint[](count);
    count = 0;
    for (uint i = 0; i < nextClaimId; i ++) {
      if (claims[i].claimer == claimer) {
          ids[count] = i;
          count ++;
      }
    }
    return ids;
  }

  // ------------------------- METHODS USED BY PROOF TYPES -------------------------

  // function getTimeBetweenThisClaimAndThatClaimersPreviousOne archived in MinimumInterval
  // function sumUpQuantitiesWithinIntervalBeforeThisClaim archived in MaximumQuantityPerInterval

  function countApprovedClaimsOfThisUser(address user) public returns(uint) {
    uint count = 0;
    for (uint i = 0; i < nextClaimId; i ++) {
      if (claims[i].claimer == user && claims[i].isApproved == true) {
        count ++;
      }
    }
    return count;
  }

  // ------------------------- PROOF TYPES -------------------------

  address[] public requiredProofTypes;

  // called from ProofType contracts
  function receiveProofApproval(address proofTypeAddress, uint claimId) public {
    // TODO require something as guard?
    claims[claimId].proofStatuses[proofTypeAddress] = true;
    claims[claimId].proofInteractionTimes[proofTypeAddress] = now;
    Fin4ClaimingStub(Fin4ClaimingAddress).proofApprovalPingback(address(this), proofTypeAddress, claimId, claims[claimId].claimer);
    if (_allProofTypesApprovedOnClaim(claimId)) {
      approveClaim(claimId);
    }
  }

  function receiveProofRejection(address proofTypeAddress, uint claimId) public {
    // can there be multiple interaction times per proof type?
    claims[claimId].proofInteractionTimes[proofTypeAddress] = now;
    // also store reason here? Or enough to send as message to the user from the proof type as is done currently?
    claims[claimId].rejectedByProofTypes.push(proofTypeAddress);
    if (!claims[claimId].gotRejected) {
      claims[claimId].gotRejected = true;
      Fin4ClaimingStub(Fin4ClaimingAddress).proofAndClaimRejectionPingback(address(this), claimId, claims[claimId].claimer);
    }
  }

  function approveClaim(uint claimId) private {
    claims[claimId].isApproved = true;
    claims[claimId].claimApprovalTime = now;
    Fin4ClaimingStub(Fin4ClaimingAddress).claimApprovedPingback(address(this), claims[claimId].claimer, claimId,
      claims[claimId].quantity, Fin4ClaimingHasMinterRole);
  }

  function isMinter(address account) public view returns (bool);

  function addMinter(address account) public;

  function renounceMinter() public;

  function mint(address account, uint256 amount) public returns (bool);

  function _allProofTypesApprovedOnClaim(uint claimId) private view returns(bool) {
    for (uint i = 0; i < requiredProofTypes.length; i ++) {
      if (!claims[claimId].proofStatuses[requiredProofTypes[i]]) {
        return false;
      }
    }
    return true;
  }

  function getRequiredProofTypes() public view returns(address[] memory) {
    return requiredProofTypes;
  }

  function addProofTypes(address Fin4ProvingAddr, address[] memory _requiredProofTypes) public {
    Fin4ProvingAddress = Fin4ProvingAddr;
    Fin4Proving proving = Fin4Proving(Fin4ProvingAddress);

    for (uint i = 0; i < _requiredProofTypes.length; i++) {
      address proofType = _requiredProofTypes[i];

      require(proving.proofTypeIsRegistered(proofType), "This address is not registered as proof type in Fin4Proving");
      requiredProofTypes.push(proofType);
      Fin4BaseProofType(proofType).registerTokenCreator(tokenCreator);
    }
  }

  // function getUnrejectedClaimsWithThisProofTypeUnapproved archived in SensorOneTimeSignal

  function proofTypeIsRequired(address proofType, uint claimId) public view returns(bool) {
    for (uint i = 0; i < claims[claimId].requiredProofTypes.length; i ++) {
      if (claims[claimId].requiredProofTypes[i] == proofType) {
          return true;
      }
    }
    return false;
  }
}
