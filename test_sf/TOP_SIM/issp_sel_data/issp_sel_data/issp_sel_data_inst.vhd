	component issp_sel_data is
		port (
			source : out std_logic_vector(0 downto 0)   -- source
		);
	end component issp_sel_data;

	u0 : component issp_sel_data
		port map (
			source => CONNECTED_TO_source  -- sources.source
		);

