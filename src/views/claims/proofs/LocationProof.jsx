import React, { useState, useRef, useEffect } from 'react';
import { drizzleConnect } from 'drizzle-react';
import { useTranslation } from 'react-i18next';
import PropTypes from 'prop-types';

function LocationProof(props, context) {
	const { t } = useTranslation();

	const [value, setValue] = useState(null);
	const values = useRef({});

	useEffect(() => {});

	return 'TODO';
}

LocationProof.contextTypes = {
	drizzle: PropTypes.object
};

const mapStateToProps = state => {
	return {};
};

export default drizzleConnect(LocationProof, mapStateToProps);
