pragma solidity ^0.5.17;

import 'contracts/underlyings/BaseSourcerer.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";

contract MintingSourcerer is BaseSourcerer {

    function convert(address pat, address collateral, uint amount) public {
        bytes32 id = getId(pat, collateral);
        fetchAndBurnPAT(pat, msg.sender, amount);

        uint exchangeAmount = amount * pairs[id].exchangeRatio;

        // mint COLLATERAL, requires this contract to have the minter role
        ERC20Mintable(collateral).mint(getBeneficiary(id, msg.sender), exchangeAmount);

        pairs[id].totalExchangedPatAmount += amount;
        pairs[id].totalCollateralBalance += exchangeAmount; // gets up too because of minting
    }

    function getParameterForTokenCreatorToSetEncoded() public pure returns(string memory) {
        return "address:collateral:address of token to mint,address:beneficiary:leave blank for it to be the claimer,"
            "uint:exchangeRatio:give n get n*x collateral minted";
    }

}
