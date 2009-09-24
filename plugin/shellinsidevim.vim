" Vim global functions for running shell commands
" Version: 2.7
" Maintainer: WarGrey <juzhenliang@gmail.com>
" Last change: 2009 Sep 24
"
"*******************************************************************************
"
" --Typing the Ex command "Shell" will also allow you to run a Shell which you
"   give and pass up to 20 parameters to that shell.
"
"   Sample syntax...
"       :Shell ps -e
"
" --Pressing "F4" will toggle the display of a buffer containing the output
"   produced when running the shell command.
"
" **************************Some special syntax format**************************
"
" --If a Shell command starts with ":", this Shell will be executed as a vim Ex
"  command, this is convenience if you map this command to a shortcut such as:
"
"  map <CR> :Shell
"
"  Then you could use this script to execute all the normal command directly.
"
"  --If a Shell command starts with ">", this Shell will be executed with inputs
"  which come from a file which name is ".VIM_STD_IN". If the input file is not 
"  exsits, you could give the inputs line by line by typing directly.
"
"  --If a Shell command ends with ";", this Shell will be executed as a program
"  development tool. You could use this script for your development, then you 
"  could pass the compile or interpret command as the Shell parameters with ";"
"  followed. When the command finished it will jump to the first error line if
"  there are some errors. Of caurse you should special a compiler first.
"
"*******************************************************************************

if exists("b:load_shellinsidevim") && b:load_shellinsidevim==1
	finish
endif
let b:load_shellinsidevim=1

runtime! plugin/common.vim

if !exists("g:AutoShowOutputWindow")
	let g:AutoShowOutputWindow=0
endif
if !exists("g:ShowOutputInCommandline")
	let g:ShowOutputInCommandline=0
endif
if !exists("g:ShowOutputWindowWhenVimLaunched")
	let g:ShowOutputWindowWhenVimLaunched=1
endif

let s:Results=[]
let g:CurrentCommandResult=''

" Ex command which take 0 or more ( up to 20 ) parameters
command -complete=file -nargs=* Shell call g:ExecuteCommand(<f-args>)
map <unique> <silent> <F4> :call <SID>ToggleOutputWindow()<CR>
map <silent> <C-F4> :messages<CR>
imap <unique> <silent> <F4> <ESC><F4>a
imap <silent> <C-F4> <ESC><C-F4>a

function! g:ExecuteCommand(...)
	if a:0==0
		call g:EchoWarningMsg(s:GetCmdPreffix("")." <NOTHING TO EXECUTE>")
		return
	endif

	try
		let parms=map(deepcopy(a:000),'g:Trim(v:val)')
		let msg=join(parms,' ')
		let cmd=join(map(parms,'substitute(expand(v:val),"\n"," ","g")'),' ')
		if msg=~'^\s*>*\s*:'
			call s:ExecuteVimcmd(msg,cmd)
		else
			call s:ExecuteShell(msg,cmd)
		endif
	catch /.*/
		call g:EchoErrorMsg(v:exception.' at '.v:throwpoint.' ')
	endtry
endfunction

"Display a buffer containing the contents of s:Results
function! g:DisplayOutput()
	if g:AutoShowOutputWindow || bufloaded("VIM_STD_OUTPUT")>0
		if bufloaded("VIM_STD_OUTPUT")>0
			silent! bwipeout VIM_STD_OUTPUT
		endif
		call s:ToggleOutputWindow()
	endif
	if g:ShowOutputInCommandline
		echo g:CurrentCommandResult
	endif
endfunction

function! s:ToggleOutputWindow()
	if bufloaded("VIM_STD_OUTPUT")==0 
		if strlen(&buftype) > 0 && bufname("%") != "VIM_STD_OUTPUT"
			call g:EchoWarningMsg("This buffer does not have the output windows!")
			return
		endif
		
		let this=bufwinnr("%")
		let @r=join(s:Results,"").s:GetCmdPreffix("SHELL")." "
		silent! rightbelow new VIM_STD_OUTPUT
		syntax match shell "\[SHELL@.*\].*$" contains=command
		syntax match command "\s.*$" contained
		syntax match innercmd "^>>.*$"
		syntax match interrupt "^\s*Vim:Interrupt\s*$"
		syntax match failinfo "^\s*ExecuteCommand failed:.*$"
		highlight def shell ctermfg=green guifg=green
		highlight def command ctermfg=darkcyan guifg=darkcyan
		highlight def innercmd ctermfg=gray guifg=gray
		highlight def interrupt ctermfg=red guifg=red
		highlight def failinfo ctermfg=red guifg=red
		resize 8
		setlocal buftype=nofile
		setlocal readonly 
		silent normal "rP
		execute 'silent normal '.(1+len(split(@r,"\n"))).'gg$'
		setlocal nomodifiable
		execute this."wincmd w"
	elseif bufloaded("VIM_STD_OUTPUT") > 0
		silent! bwipeout VIM_STD_OUTPUT
	endif
endfunction

" Some useful private functions
function! s:GetCmdPreffix(type)
	return "[".a:type."@".fnamemodify(getcwd(),":~").":".fnamemodify(bufname('%'),":.")."] "
endfunction

function! s:ExecuteVimcmd(vimmsg,vimcmd)
	let msg=substitute(a:vimmsg,'\(^\s*>*\s*\)\|\(\s*;\s*$\)','','g')
	call g:EchoMoreMsg(s:GetCmdPreffix("ViM").msg)
	execute msg
endfunction

function! s:ExecuteShell(shellmsg,shellcmd)
	let shellcmd=substitute(a:shellcmd,'\s*;*\s*$','','g')
	let rein=''
	if match(a:shellmsg,'^\s*>>\s*')==0
		let shellcmd=substitute(shellcmd,'^\s*>>\s*','','g')
		if !filereadable('.VIM_STD_IN')
			call writefile([],'.VIM_STD_IN')
		endif
		let rein=' 0<.VIM_STD_IN'
	elseif match(a:shellmsg,'^\s*>\s*')==0
		let shellcmd=substitute(shellcmd,'^\s*>\s*','','g')
		if !filereadable('.VIM_STD_IN')
			let choice=confirm("Input-file not found, give now?","&Yes\n&No",1)
			if choice!=1
				call g:EchoWarningMsg("Missing inputs which are required, The application may be aborted!")
				call writefile([],'.VIM_STD_IN')
			else
				echo 'Pease give the inputs line by line util "EOF" given.'
				let lines=[]
				let line=input("")
				while line != "EOF"
					call add(lines,line)
					let line=input("")
				endwhile
				call writefile(lines,'.VIM_STD_IN')
			endif
		endif
		let rein=' 0<.VIM_STD_IN'
	endif
	
	let cmd=s:GetCmdPreffix("SHELL").shellcmd
	call g:EchoMoreMsg(cmd)
	try
		if shellcmd=~'^\s*cd '
			execute shellcmd
			let g:CurrentCommandResult=''
		else
			let g:CurrentCommandResult=system('cd '.getcwd().' && '.shellcmd.rein)
		endif
	catch /.*/
		let g:CurrentCommandResult=v:exception.' at '.v:throwpoint."\n"
	endtry
	if v:shell_error!=0
		let error="ExecuteCommand failed: shell exit code ".v:shell_error
		let g:CurrentCommandResult.=((g:CurrentCommandResult=~'\n$')?"":"\n").error."\n"
		call g:EchoWarningMsg(error)
	endif

	if a:shellmsg=~'^\s*>*\s*clear\s*;*\s*$'
		let s:Results=[]
		let g:CurrentCommandResult=''
	else
		if &history>0 && len(s:Results)==&history
			call remove(s:Results,0)
		endif
		call g:AddShellCommandResult(cmd."\n")
		call g:AddShellCommandResult(g:CurrentCommandResult,match(a:shellmsg,'\s*;\s*$')>-1)
	endif

	try
		let @+=g:CurrentCommandResult
	catch
	endtry

	call g:DisplayOutput()
endfunction

function! g:AddShellCommandResult(results,...)
	let added=''
	let typeid=type(a:results)
	if typeid==type([])
		let added=join(a:results,"\n")
	elseif typeid==type("")
		let added=g:Trim(a:results)
	endif
	if len(added)>len('')
		call add(s:Results,added)
	endif
	if ((a:0>=1)?(a:1):0)
		cexpr a:results
	endif
endfunction

if g:ShowOutputWindowWhenVimLaunched>0
	call s:ToggleOutputWindow()
endif
