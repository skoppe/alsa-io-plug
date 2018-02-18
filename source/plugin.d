import std.stdio;
import deimos.alsa.pcm;
import deimos.alsa.conf;
import deimos.alsa.global;
import core.stdc.errno;
import std.string;


extern (C) {
  alias snd_lib_error_handler_t = __gshared void function(const char *file, int line, const char *f, int err, const char *fmt,...);
  extern snd_lib_error_handler_t snd_lib_error;
  export int _snd_pcm_test_open (snd_pcm_t **pcmp, const char *name,
                                 snd_config_t *root, snd_config_t *conf,
                                 snd_pcm_stream_t stream, int mode)  {
    snd_lib_error(__FILE__.toStringz, __LINE__, __FUNCTION__.toStringz, 0, "Stuff bla stuff".toStringz);
    return -EINVAL;
  }
  export char __snd_pcm_test_open_dlsym_pcm_001;
}


