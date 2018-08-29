all: automated_nightly_music_files.zip Music
	./transfer_music

Music:
	unzip automated_nightly_music_files.zip

automated_nightly_music_files.zip:
	./download https://dav.nomovok.info/C4C/testing/automatedtesting/test_data/automated_nightly_music_files.zip
