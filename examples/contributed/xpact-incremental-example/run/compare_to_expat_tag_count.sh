
clear
echo Installing xpact_example
cp -u build/linux-x86-64/EIFGENs/classic/F_code/xpact_example ~/.local/bin

pushd .

cd ~/Dev/C

echo
echo Benchmarking Eiffel Xpact and C eXpat
echo

for name in ns_att_test.xml recset.xml wordnet_glossary-20010201.rdf; do
	echo USING\: eXpat XML parser \(pure C\)
	xmlcount_byfreq libexpat/testdata/largefiles/$name
	echo

	echo USING\: Xpact XML parser \(Eiffel\)
	xpact_example count_tags libexpat/testdata/largefiles/$name
done

popd


