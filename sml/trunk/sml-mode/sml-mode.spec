%define lispdir		%{_datadir}/emacs/site-lisp
%define startupfile	%{lispdir}/site-start.el

Summary:	Emacs mode for editing Standard ML source code
Name:		sml-mode
Version:	$Name$
Release:	0.1
Group:		Applications/Editors
Copyright:	GPL
Packager:	Stefan Monnier
Source:		ftp://flint.cs.yale.edu/pub/monnier/%{name}/%{name}.tar.gz
Buildroot:	%{_tmppath}/%{name}-buildroot
BuildPreReq:	emacs >= 20 xemacs >= 21
BuildArch:	noarch

%description
SML-MODE is a major Emacs mode for editing Standard ML. It provides
syntax highlighting and automatic indentation and comes with sml-proc
which allows interaction with an inferior SML interactive loop.

%prep
%setup -q -n %{name}

%install
make install \
  prefix=%{buildroot}%{_prefix} \
  infodir=%{buildroot}%{_infodir} \
  lispdir=%{buildroot}%{lispdir}
gzip -9f %{buildroot}%{lispdir}/sml-mode/*.el

texi2pdf sml-mode.texi

%post
cat >> %{lispdir}/site-start.el <<EOF
;; sml-mode-start
;; This section was automatically generated by rpm
(load "sml-mode-startup")
;; End of automatically generated section
;; sml-mode-end
EOF

/sbin/install-info %{_infodir}/sml-mode.info.gz %{_infodir}/dir \
    --section=Emacs \
    --entry="* SML: (sml-mode).    Editing & Running Standard ML from Emacs"

%postun
ed -s %{lispdir}/site-start.el <<EOF
/^;; sml-mode-start$/,/^;; sml-mode-end$/d
wq
EOF

/sbin/install-info --delete %{_infodir}/sml-mode.info.gz %{_infodir}/dir \
    --section=Emacs \
    --entry="* SML: (sml-mode).    Editing & Running Standard ML from Emacs"

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root)
%doc BUGS ChangeLog INSTALL NEWS README TODO
%doc sml-mode.texi sml-mode.pdf
%doc %{_infodir}/*.info*
%dir %{lispdir}/%{name}
%{lispdir}/%{name}/*.elc
%{lispdir}/%{name}/*.el
%{lispdir}/%{name}/*.el.*

%changelog
