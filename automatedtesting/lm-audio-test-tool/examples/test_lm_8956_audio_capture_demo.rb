require 'test_helper'
require 'enjoy_music/enjoy_music_helper'
require 'open3'

include EnjoyMusicHelper

# This is an audio test tool example/demo test.
# How to run:
# rake run_tests[<sut config id>] TEST=example_tests/test_lm_8956_audio_capture_demo.rb
class Test8956 < Minitest::Test
  SONG_TITLE = 'sin 1kHz 0.8 wav'
  EXPECTED_PEAK_FREQ = 1000.0 # Hz
  PEAK_FREQ_TOL = 100      # Hz
  THD_PLUS_N_MAX = 0.05    # 0-1

  # Test function needs to be named in format: test_<jira test key>
  def test_lm_8956
    log "Running test #{function_label}: Audio capture POC demo"
    initialize_test

    assert(@sut_configuration['audiotest_enabled'], "Audio testing is not enabled in sut config")

    require 'audio_test_tool'
    # Set AudioTestTool configuration
    AudioTestTool.configure(device: @sut_configuration['audiotest_device']) if @sut_configuration.include?('audiotest_device')
    AudioTestTool.configure(channels: @sut_configuration['audiotest_channels']) if @sut_configuration.include?('audiotest_channels')
    AudioTestTool.configure(samplerate: @sut_configuration['audiotest_samplerate']) if @sut_configuration.include?('audiotest_samplerate')
    AudioTestTool.configure(time: '5')

    go_to_enjoy_tab
    go_to_music_mode(reset: true)

    sort_by_song
    music_list = get_current_music_list
    seek_music_item(SONG_TITLE, music_list)

    log "  Playing \"#{SONG_TITLE}\" for approximately 5 s..."
    play_ui = start_playback

    # START AudioTestTool recording
    begin
      filename = AudioTestTool.record(function_label)
    rescue AudioTestTool::ExecutionError => e
      log "Error executing AudioTestTool recorder"
      log e
      assert(false, 'Audio capture command failed')
    end

    # when the capture subshell exits, playback can be paused
    pause(play_ui)

    begin
      analyze_out = AudioTestTool.analyze_thdn(filename)
    rescue AudioTestTool::ExecutionError => e
      log "Error executing AudioTestTool analyzer"
      log e
      assert(false, 'Audio analyze command failed')
    end

    peak_freq = analyze_out['Frequency']
    thd_plus_n = analyze_out['THD+N']

    assert((peak_freq - EXPECTED_PEAK_FREQ).abs <  PEAK_FREQ_TOL,
           "Incorrect peak frequency #{peak_freq}, expected #{EXPECTED_PEAK_FREQ}")
    assert(thd_plus_n < THD_PLUS_N_MAX, "THD+N too high: #{thd_plus_n} > #{THD_PLUS_N_MAX} (max)")

    log "  Test #{function_label} passed!"
  end
end
