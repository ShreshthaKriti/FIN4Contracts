import React, { Component } from 'react';
import ContractForm from '../../components/ContractForm';
import Box from '../../components/Box';
import { drizzleConnect } from 'drizzle-react';
import PropTypes from 'prop-types';
import { Fin4MainAddress } from '../../config/DeployedAddresses';

class Claim extends Component {
	constructor(props) {
		super(props);
	}

	render() {
		return (
			<Box title={'Claim an Action'}>
				<ContractForm
					contractAddress={Fin4MainAddress}
					contractName="Fin4Main"
					method="submitClaim"
					labels={['Action type', 'Quantity', 'Date', 'Comment']}
					singleSelectOptions={this.props.fin4Tokens}
				/>
			</Box>
		);
	}
}

Claim.contextTypes = {
	drizzle: PropTypes.object
};

const mapStateToProps = state => {
	return {
		contracts: state.contracts,
		fin4Tokens: state.fin4Store.fin4Tokens
	};
};

export default drizzleConnect(Claim, mapStateToProps);
