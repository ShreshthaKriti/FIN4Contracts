import React from 'react';
import { drizzleConnect } from 'drizzle-react';
import Container from '../../components/Container';
import Messages from '../Actions/Messages';
import Box from '../../components/Box';
import Table from '../../components/Table';
import TableRow from '../../components/TableRow';
import styled from 'styled-components';
import Currency from '../../components/Currency';
import { useTranslation } from 'react-i18next';
const config = require('../../config/deployment-config.json');
const axios = require('axios');

function Home(props) {
	const { t, i18n } = useTranslation();
	return (
		<Container>
			<Messages />
			<Box title={t('your-token-balances')}>
				{Object.keys(props.usersBalances).length === 0 ? (
					<NoTokens>{t('no-tokens-yet')}</NoTokens>
				) : (
					<Table headers={[t('token-name'), t('token-balance')]}>
						{Object.keys(props.usersBalances).map((tokenAddr, index) => {
							let token = props.store.getState().fin4Store.fin4Tokens[tokenAddr];
							return (
								<TableRow
									key={'balance_' + index}
									data={{
										name: (
											<Currency
												symbol={token.symbol}
												name={token.name}
												href={'https://rinkeby.etherscan.io/address/' + tokenAddr}
											/>
										),
										balance: props.usersBalances[tokenAddr]
									}}
								/>
							);
						})}
					</Table>
				)}
			</Box>
			<Box title={t('about-you')}>
				<p style={{ fontFamily: 'arial' }}>
					{t('your-public-address')}
					<br />
					<small>
						{props.defaultAccount === null ? (
							t('info-not-yet-available')
						) : (
							// TODO make network-generic
							<a href={'https://rinkeby.etherscan.io/address/' + props.defaultAccount} target="_blank">
								{props.defaultAccount}
							</a>
						)}
					</small>
				</p>
				<p style={{ fontFamily: 'arial' }}>
					Your balance:{' '}
					{props.usersEthBalance === null
						? t('info-not-yet-available')
						: // TODO dynamic rounding / unit?
						  Math.round(props.usersEthBalance * 1000) / 1000}{' '}
					ETH
				</p>
				{config.FAUCET_URL && (
					<a
						href="#"
						onClick={() => {
							let recipient = props.defaultAccount;
							let networkID = window.ethereum.networkVersion;
							let encodedURL = config.FAUCET_URL + '/faucet?recipient=' + recipient + '&networkID=' + networkID;
							console.log('Calling faucet server: ' + encodedURL);
							axios
								.get(encodedURL)
								.then(response => {
									console.log('Successfully called faucet server. Response: ' + response.data);
									alert(response.data);
								})
								.catch(error => {
									console.log('Error calling faucet server', error);
									alert('Failed to request Ether');
								})
								.finally(() => {});
						}}>
						<RequestEth>{t('request-ether')}</RequestEth>
					</a>
				)}
			</Box>
		</Container>
	);
}

const RequestEth = styled.div`
	font-family: arial;
	font-size: small;
	color: gray;
`;

const NoTokens = styled.div`
	font-family: arial;
	text-align: center;
	color: silver;
`;

const mapStateToProps = state => {
	return {
		usersBalances: state.fin4Store.usersBalances,
		defaultAccount: state.fin4Store.defaultAccount,
		usersEthBalance: state.fin4Store.usersEthBalance
	};
};

export default drizzleConnect(Home, mapStateToProps);
