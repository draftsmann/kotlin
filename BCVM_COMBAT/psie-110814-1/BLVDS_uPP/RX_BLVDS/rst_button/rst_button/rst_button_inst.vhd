	component rst_button is
		port (
			source : out std_logic_vector(0 downto 0)   -- source
		);
	end component rst_button;

	u0 : component rst_button
		port map (
			source => CONNECTED_TO_source  -- sources.source
		);

