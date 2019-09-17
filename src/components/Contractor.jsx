import { Fin4MainAddress, PLCRVotingAddress } from '../config/DeployedAddresses.js';
import { ADD_MULTIPLE_FIN4_TOKENS, ADD_MULTIPLE_CLAIMS, ADD_ADDRESS } from '../middleware/actionTypes';
const BN = require('bignumber.js');

const getContract = (contractAddress, contractName) => {
	const contract = require('truffle-contract');
	const json = require('../build/contracts/' + contractName + '.json');
	let Contractor = contract({
		abi: json.abi
	});
	Contractor.setProvider(window.web3.currentProvider);
	return Contractor.at(contractAddress);
};

const getContractData = (contract, contractJson, method, methodArgs = []) => {
	const currentAccount = window.web3.currentProvider.selectedAddress;

	return getContract(contract, contractJson).then(instance => {
		return instance[method].call(...methodArgs, {
			from: currentAccount
		});
	});
};

let loadedAllInitalDataIntoTheStore = false;

const loadInitialDataIntoStore = (props, callback) => {
	if (loadedAllInitalDataIntoTheStore) {
		return;
	}

	getContractData(Fin4MainAddress, 'Fin4Main', 'getTCRaddresses').then(
		({ 0: REPToken, 1: GOVToken, 2: Registry, 3: PLCRVoting }) => {
			props.dispatch({
				type: ADD_ADDRESS,
				name: 'REPToken',
				address: REPToken
			});
			props.dispatch({
				type: ADD_ADDRESS,
				name: 'GOVToken',
				address: GOVToken
			});
			props.dispatch({
				type: ADD_ADDRESS,
				name: 'Registry',
				address: Registry
			});
			props.dispatch({
				type: ADD_ADDRESS,
				name: 'PLCRVoting',
				address: PLCRVoting
			});

			// load all Fin4 tokens into the store
			loadAllFin4TokensIntoStoreIfNotDoneYet(props, () => {
				loadedAllInitalDataIntoTheStore = true;
				callback();
			});
		}
	);
};

let loadedAllFin4TokensIntoTheStore = false;

const loadAllFin4TokensIntoStoreIfNotDoneYet = (props, callback) => {
	if (loadedAllFin4TokensIntoTheStore) {
		return;
	}
	getContractData(Fin4MainAddress, 'Fin4Main', 'getChildren')
		.then(tokens => {
			return tokens.map(address => {
				return getContractData(address, 'Fin4Token', 'getInfo').then(({ 0: name, 1: symbol, 2: description }) => {
					return {
						address: address,
						name: name,
						symbol: symbol,
						description: description
					};
				});
			});
		})
		.then(promises => Promise.all(promises))
		.then(tokenArr => {
			props.dispatch({
				type: ADD_MULTIPLE_FIN4_TOKENS,
				tokenArr: tokenArr
			});
			loadedAllFin4TokensIntoTheStore = true;
			if (callback) {
				callback();
			}
		});
};

let loadedAllCurrentUsersClaimsIntoTheStore = false;

const loadAllCurrentUsersClaimsIntoStoreIfNotDoneYet = props => {
	if (loadedAllCurrentUsersClaimsIntoTheStore) {
		return;
	}
	getContractData(Fin4MainAddress, 'Fin4Main', 'getActionsWhereUserHasClaims')
		.then(tokenAddresses => {
			return tokenAddresses.map(tokenAddr => {
				return getContractData(tokenAddr, 'Fin4Token', 'getMyClaimIds').then(claimIds => {
					return claimIds.map(claimId => {
						return getContractData(tokenAddr, 'Fin4Token', 'claims', [claimId]).then(
							({
								0: claimIdBN,
								1: claimer,
								2: isApproved,
								3: quantityBN,
								4: dateBN,
								5: comment,
								6: proof_statuses
							}) => {
								let claimId = new BN(claimIdBN).toNumber();
								return {
									id: tokenAddr + '_' + claimId, // pseudoId
									token: tokenAddr,
									claimId: claimId,
									claimer: claimer,
									isApproved: isApproved,
									quantity: new BN(quantityBN).toNumber(),
									date: new BN(dateBN).toNumber(),
									comment: comment
								};
							}
						);
					});
				});
			});
		})
		.then(promises => Promise.all(promises))
		.then(data => data.flat())
		.then(promises => Promise.all(promises))
		.then(claimArr => {
			props.dispatch({
				type: ADD_MULTIPLE_CLAIMS,
				claimArr: claimArr
			});
			loadedAllCurrentUsersClaimsIntoTheStore = true;
		});
};

// DEPRECATED
const getAllActionTypes = () => {
	return getContractData(Fin4MainAddress, 'Fin4Main', 'getChildren')
		.then(tokens => {
			return tokens.map(address => {
				return getContractData(address, 'Fin4Token', 'getInfo').then(({ 0: name, 1: symbol, 2: description }) => {
					return {
						value: address,
						label: `[${symbol}] ${name}`
					};
				});
			});
		})
		.then(data => Promise.all(data));
};

const getPollStatus = pollID => {
	// pollID is also called challengeID in Registry.sol
	return getContractData(PLCRVotingAddress, 'PLCRVoting', 'pollMap', [pollID]).then(
		({ 0: commitEndDateBN, 1: revealEndDateBN, 2: voteQuorum, 3: votesFor, 4: votesAgainst }) => {
			let commitEndDate = new BN(commitEndDateBN).toNumber() * 1000;
			let revealEndDate = new BN(revealEndDateBN).toNumber() * 1000;
			let nowTimestamp = Date.now();

			if (commitEndDate - nowTimestamp > 0) {
				return {
					inPeriod: PollStatus.IN_COMMIT_PERIOD,
					dueDate: new Date(commitEndDate).toLocaleString('de-CH-1996') // choose locale automatically?
				};
			}

			if (revealEndDate - nowTimestamp > 0) {
				return {
					inPeriod: PollStatus.IN_REVEAL_PERIOD,
					dueDate: new Date(revealEndDate).toLocaleString('de-CH-1996')
				};
			}

			return {
				inPeriod: PollStatus.PAST_REVEAL_PERIOD,
				dueDate: ''
			};
		}
	);
};

const PollStatus = {
	IN_COMMIT_PERIOD: 'Commit Vote',
	IN_REVEAL_PERIOD: 'Reveal',
	PAST_REVEAL_PERIOD: '-'
};

export {
	getContractData,
	getContract,
	getAllActionTypes,
	getPollStatus,
	PollStatus,
	loadInitialDataIntoStore,
	loadAllFin4TokensIntoStoreIfNotDoneYet,
	loadAllCurrentUsersClaimsIntoStoreIfNotDoneYet
};
