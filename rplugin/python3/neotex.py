from time import sleep
import neovim


@neovim.plugin
class NeoTex(object):
    def __init__(self, vim):
        self.vim = vim

    @neovim.function('_neotex_init', sync=True)
    def init(self, args):
        self.wait = False
        self.delay = self.vim.vars.get('neotex_delay', 1.0)/1000.0
        self.latexdiff = bool(self.vim.vars.get('neotex_latexdiff', 0))
        self.tempname = args[0]
        self.vim

    @neovim.command('NeoTex')
    def cmd_neotex(self):
        if self.vim.funcs.exists('b:neotex_jobexe'):
            self.vim.async_call(self.write)

    @neovim.function('NeoTexUpdate')
    def update(self, args):
        if not self.wait:
            self.vim.async_call(self.write_wait)

    def write_wait(self):
        self.wait = True
        sleep(self.delay)
        self.write()
        self.wait = False

    def write(self):
        buff = self.vim.current.buffer
        exe = self.vim.eval('b:neotex_jobexe')
        with open(self.tempname, 'w') as f:
            f.write('\n'.join(buff))
        self.vim.funcs.jobstart(['bash', '-c', exe],
                                {'cwd': self.vim.funcs.expand('%:p:h')})
