import React, { useState, useEffect } from 'react';
import { drizzleConnect } from 'drizzle-react';
import { useTranslation } from 'react-i18next';
import Container from '../../components/Container';
import Box from '../../components/Box';
import PropTypes from 'prop-types';
import { findTokenBySymbol } from '../../components/Contractor';
import Currency from '../../components/Currency';
import { Link } from 'react-router-dom';

function TokenEdit(props, context) {
	const { t } = useTranslation();

	const [tokenViaURL, setTokenViaURL] = useState(null);

	useEffect(() => {
		let symbol = props.match.params.tokenSymbol;
		if (!tokenViaURL && Object.keys(props.fin4Tokens).length > 0 && symbol) {
			let token = findTokenBySymbol(props, symbol);
			if (token) {
				setTokenViaURL(token);
			}
		}
	});

	return (
		<>
			<Container>
				{tokenViaURL && (
					<>
						<Box>
							<center style={{ fontFamily: 'arial' }}>
								<Currency symbol={tokenViaURL.symbol} name={<b>{tokenViaURL.name}</b>} />
								<br />
								{!(tokenViaURL.userIsCreator || tokenViaURL.userIsAdmin) && (
									<>
										<br />
										<span style={{ color: 'red' }}>You don't have editing rights on this token.</span>
										<br />
									</>
								)}
								<br />
								<Link to={'/token/details/' + tokenViaURL.symbol}>Token details</Link>
							</center>
						</Box>
						{tokenViaURL.userIsAdmin && <Box title="Manage proof types"></Box>}
						{tokenViaURL.userIsCreator && <Box title="Manage admins"></Box>}
					</>
				)}
			</Container>
		</>
	);
}

TokenEdit.contextTypes = {
	drizzle: PropTypes.object
};

const mapStateToProps = state => {
	return {
		fin4Tokens: state.fin4Store.fin4Tokens
	};
};

export default drizzleConnect(TokenEdit, mapStateToProps);