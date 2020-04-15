	component issp is
		port (
			source : out std_logic_vector(1 downto 0)   -- source
		);
	end component issp;

	u0 : component issp
		port map (
			source => CONNECTED_TO_source  -- sources.source
		);

