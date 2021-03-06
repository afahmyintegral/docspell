{config, lib, pkgs, ...}:

with lib;
let
  cfg = config.services.docspell-joex;
  user = if cfg.runAs == null then "docspell" else cfg.runAs;
  configFile = pkgs.writeText "docspell-joex.conf" ''
  {"docspell": { "joex":
       ${builtins.toJSON cfg}
  }}
  '';
  defaults = {
    app-id = "joex1";
    base-url = "http://localhost:7878";
    bind = {
      address = "localhost";
      port = 7878;
    };
    jdbc = {
      url = "jdbc:h2:///tmp/docspell-demo.db;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;AUTO_SERVER=TRUE";
      user = "sa";
      password = "";
    };
    scheduler = {
      pool-size = 2;
      counting-scheme = "4,1";
      retries = 5;
      retry-delay = "1 minute";
      log-buffer-size = 500;
      wakeup-period = "30 minutes";
    };
    extraction = {
      pdf = {
        min-text-len = 10;
      };

      ocr = {
        max-image-size = 14000000;
        page-range = {
          begin = 10;
        };
        ghostscript =  {
          working-dir = "/tmp/docspell-extraction";
          command = {
            program = "${pkgs.ghostscript}/bin/gs";
            args = [ "-dNOPAUSE" "-dBATCH" "-dSAFER" "-sDEVICE=tiffscaled8" "-sOutputFile={{outfile}}" "{{infile}}" ];
            timeout = "5 minutes";
          };
        };
        unpaper = {
          command = {
            program = "${pkgs.unpaper}/bin/unpaper";
            args = [ "{{infile}}" "{{outfile}}" ];
            timeout = "5 minutes";
          };
        };
        tesseract = {
          command= {
            program = "${pkgs.tesseract4}/bin/tesseract";
            args = ["{{file}}" "stdout" "-l" "{{lang}}" ];
            timeout = "5 minutes";
          };
        };
      };
    };
    convert = {
      chunk-size = 524288;
      max-image-size = 14000000;

      markdown = {
        internal-css = ''
            body { padding: 2em 5em; }
          '';
      };

      wkhtmlpdf = {
        command = {
          program = "${pkgs.wkhtmltopdf}/bin/wkhtmltopdf";
          args = ["-s" "A4" "--encoding" "UTF-8" "-" "{{outfile}}"];
          timeout = "2 minutes";
        };
        working-dir = "/tmp/docspell-convert";
      };

      tesseract = {
        command = {
          program = "${pkgs.tesseract4}/bin/tesseract";
          args = ["{{infile}}" "out" "-l" "{{lang}}" "pdf" "txt"];
          timeout = "5 minutes";
        };
        working-dir = "/tmp/docspell-convert";
      };

      unoconv = {
        command = {
          program = "${pkgs.unoconv}/bin/unoconv";
          args = ["-f" "pdf" "-o" "{{outfile}}" "{{infile}}"];
          timeout = "2 minutes";
        };
        working-dir = "/tmp/docspell-convert";
      };
    };
  };
in {

  ## interface
  options = {
    services.docspell-joex = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable docspell docspell job executor.";
      };
      runAs = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Specify a user for running the application. If null, a new
          user is created.
        '';
      };

      app-id = mkOption {
        type = types.str;
        default = defaults.app-id;
        description = "The node id. Must be unique across all docspell nodes.";
      };

      base-url = mkOption {
        type = types.str;
        default = defaults.base-url;
        description = "The base url where attentive is deployed.";
      };

      bind = mkOption {
        type = types.submodule({
          options = {
            address = mkOption {
              type = types.str;
              default = defaults.bind.address;
              description = "The address to bind the REST server to.";
            };
            port = mkOption {
              type = types.int;
              default = defaults.bind.port;
              description = "The port to bind the REST server";
            };
          };
        });
        default = defaults.bind;
        description = "Address and port bind the rest server.";
      };

      jdbc = mkOption {
        type = types.submodule ({
          options = {
            url = mkOption {
              type = types.str;
              default = defaults.jdbc.url;
              description = ''
                The URL to the database. By default a file-based database is
                used. It should also work with mariadb and postgresql.

                Examples:
                   "jdbc:mariadb://192.168.1.172:3306/docspell"
                   "jdbc:postgresql://localhost:5432/docspell"
                   "jdbc:h2:///home/dbs/docspell.db;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;AUTO_SERVER=TRUE"

              '';
            };
            user = mkOption {
              type = types.str;
              default = defaults.jdbc.user;
              description = "The user name to connect to the database.";
            };
            password = mkOption {
              type = types.str;
              default = defaults.jdbc.password;
              description = "The password to connect to the database.";
            };
          };
        });
        default = defaults.jdbc;
        description = "Database connection settings";
      };

      scheduler = mkOption {
        type = types.submodule({
          options = {
            pool-size = mkOption {
              type = types.int;
              default = defaults.scheduler.pool-size;
              description = "Number of processing allowed in parallel.";
            };
            counting-scheme = mkOption {
              type = types.str;
              default = defaults.scheduler.counting-scheme;
              description = ''
                A counting scheme determines the ratio of how high- and low-prio
                jobs are run. For example: 4,1 means run 4 high prio jobs, then
                1 low prio and then start over.
              '';
            };
            retries = mkOption {
              type = types.int;
              default = defaults.scheduler.retries;
              description = ''
                How often a failed job should be retried until it enters failed
                state. If a job fails, it becomes "stuck" and will be retried
                after a delay.
              '';
            };
            retry-delay = mkOption {
              type = types.str;
              default = defaults.scheduler.retry-delay;
              description = ''
                The delay until the next try is performed for a failed job. This
                delay is increased exponentially with the number of retries.
              '';
            };
            log-buffer-size = mkOption {
              type = types.int;
              default = defaults.scheduler.log-buffer-size;
              description = ''
                The queue size of log statements from a job.
              '';
            };
            wakeup-period = mkOption {
              type = types.str;
              default = defaults.scheduler.wakeup-period;
              description = ''
                If no job is left in the queue, the scheduler will wait until a
                notify is requested (using the REST interface). To also retry
                stuck jobs, it will notify itself periodically.
              '';
            };
          };
        });
        default = defaults.scheduler;
        description = "Settings for the scheduler";
      };

      extraction = mkOption {
        type = types.submodule({
          options = {
            pdf = mkOption {
              type = types.submodule({
                options = {
                  min-text-len = mkOption {
                    type = types.int;
                    default = defaults.extraction.pdf.min-text-len;
                    description = ''
                      For PDF files it is first tried to read the text parts of the
                      PDF. But PDFs can be complex documents and they may contain text
                      and images. If the returned text is shorter than the value
                      below, OCR is run afterwards. Then both extracted texts are
                      compared and the longer will be used.
                    '';
                  };
                };
              });
              default = defaults.extraction.pdf;
              description = "Settings for PDF extraction";
            };
            ocr = mkOption {
              type = types.submodule({
                options = {
                  max-image-size = mkOption {
                    type = types.int;
                    default = defaults.extraction.ocr.max-image-size;
                    description = ''
                      Images greater than this size are skipped. Note that every
                      image is loaded completely into memory for doing OCR.
                    '';
                  };
                  page-range = mkOption {
                    type = types.submodule({
                      options = {
                        begin = mkOption {
                          type = types.int;
                          default = defaults.extraction.page-range.begin;
                          description = "Specifies the first N pages of a file to process.";
                        };
                      };
                    });
                    default = defaults.extraction.page-range;
                    description = ''
                      Defines what pages to process. If a PDF with 600 pages is
                      submitted, it is probably not necessary to scan through all of
                      them. This would take a long time and occupy resources for no
                      value. The first few pages should suffice. The default is first
                      10 pages.

                      If you want all pages being processed, set this number to -1.

                      Note: if you change the ghostscript command below, be aware that
                      this setting (if not -1) will add another parameter to the
                      beginning of the command.
                    '';
                  };
                  ghostscript = mkOption {
                    type = types.submodule({
                      options = {
                        working-dir = mkOption {
                          type = types.str;
                          default = defaults.extraction.ghostscript.working-dir;
                          description = "Directory where the extraction processes can put their temp files";
                        };
                        command = mkOption {
                          type = types.submodule({
                            options = {
                              program = mkOption {
                                type = types.str;
                                default = defaults.extraction.ghostscript.command.program;
                                description = "The path to the executable.";
                              };
                              args = mkOption {
                                type = types.listOf types.str;
                                default = defaults.extraction.ghostscript.command.args;
                                description = "The arguments to the program";
                              };
                              timeout = mkOption {
                                type = types.str;
                                default = defaults.extraction.ghostscript.command.timeout;
                                description = "The timeout when executing the command";
                              };
                            };
                          });
                          default = defaults.extraction.ghostscript.command;
                          description = "The system command";
                        };
                      };
                    });
                    default = defaults.extraction.ghostscript;
                    description = "The ghostscript command.";
                  };
                  unpaper = mkOption {
                    type = types.submodule({
                      options = {
                        command = mkOption {
                          type = types.submodule({
                            options = {
                              program = mkOption {
                                type = types.str;
                                default = defaults.extraction.unpaper.command.program;
                                description = "The path to the executable.";
                              };
                              args = mkOption {
                                type = types.listOf types.str;
                                default = defaults.extraction.unpaper.command.args;
                                description = "The arguments to the program";
                              };
                              timeout = mkOption {
                                type = types.str;
                                default = defaults.extraction.unpaper.command.timeout;
                                description = "The timeout when executing the command";
                              };
                            };
                          });
                          default = defaults.extraction.unpaper.command;
                          description = "The system command";
                        };
                      };
                    });
                    default = defaults.extraction.unpaper;
                    description = "The unpaper command.";
                  };
                  tesseract = mkOption {
                    type = types.submodule({
                      options = {
                        command = mkOption {
                          type = types.submodule({
                            options = {
                              program = mkOption {
                                type = types.str;
                                default = defaults.extraction.tesseract.command.program;
                                description = "The path to the executable.";
                              };
                              args = mkOption {
                                type = types.listOf types.str;
                                default = defaults.extraction.tesseract.command.args;
                                description = "The arguments to the program";
                              };
                              timeout = mkOption {
                                type = types.str;
                                default = defaults.extraction.tesseract.command.timeout;
                                description = "The timeout when executing the command";
                              };
                            };
                          });
                          default = defaults.extraction.tesseract.command;
                          description = "The system command";
                        };
                      };
                    });
                    default = defaults.extraction.tesseract;
                    description = "The tesseract command.";
                  };

                };
              });
              default = defaults.extraction.ocr;
              description = "";
            };
          };
        });
        default = defaults.extraction;
        description = ''
          Configuration of text extraction

          Extracting text currently only work for image and pdf files. It
          will first runs ghostscript to create a gray image from a
          pdf. Then unpaper is run to optimize the image for the upcoming
          ocr, which will be done by tesseract. All these programs must be
          available in your PATH or the absolute path can be specified
          below.
        '';
      };

      convert = mkOption {
        type = types.submodule({
          options = {
            chunk-size = mkOption {
              type = types.int;
              default = defaults.convert.chunk-size;
              description = ''
                The chunk size used when storing files. This should be the same
                as used with the rest server.
              '';
            };
            max-image-size = mkOption {
              type = types.int;
              default = defaults.convert.max-image-size;
              description = ''
                When reading images, this is the maximum size. Images that are
                larger are not processed.
              '';
            };
            markdown = mkOption {
              type = types.submodule({
                options = {
                  internal-css = mkOption {
                    type = types.str;
                    default = defaults.convert.markdown.internal-css;
                    description = ''
                      The CSS that is used to style the resulting HTML.
                    '';
                  };
                };
              });
              default = defaults.convert.markdown;
              description = ''
                Settings when processing markdown files (and other text files)
                to HTML.

                In order to support text formats, text files are first converted
                to HTML using a markdown processor. The resulting HTML is then
                converted to a PDF file.
              '';
            };
            wkhtmlpdf = mkOption {
              type = types.submodule({
                options = {
                  working-dir = mkOption {
                    type = types.str;
                    default = defaults.convert.wktmlpdf.working-dir;
                    description = "Directory where the conversion processes can put their temp files";
                  };
                  command = mkOption {
                    type = types.submodule({
                      options = {
                        program = mkOption {
                          type = types.str;
                          default = defaults.convert.wkhtmlpdf.command.program;
                          description = "The path to the executable.";
                        };
                        args = mkOption {
                          type = types.listOf types.str;
                          default = defaults.convert.wkhtmlpdf.command.args;
                          description = "The arguments to the program";
                        };
                        timeout = mkOption {
                          type = types.str;
                          default = defaults.convert.wkhtmlpdf.command.timeout;
                          description = "The timeout when executing the command";
                        };
                      };
                    });
                    default = defaults.convert.wkhtmlpdf.command;
                    description = "The system command";
                  };
                };
              });
              default = defaults.convert.wkhtmlpdf;
              description = ''
                To convert HTML files into PDF files, the external tool
                wkhtmltopdf is used.
              '';
            };
            tesseract = mkOption {
              type = types.submodule({
                options = {
                  working-dir = mkOption {
                    type = types.str;
                    default = defaults.convert.tesseract.working-dir;
                    description = "Directory where the conversion processes can put their temp files";
                  };
                  command = mkOption {
                    type = types.submodule({
                      options = {
                        program = mkOption {
                          type = types.str;
                          default = defaults.convert.tesseract.command.program;
                          description = "The path to the executable.";
                        };
                        args = mkOption {
                          type = types.listOf types.str;
                          default = defaults.convert.tesseract.command.args;
                          description = "The arguments to the program";
                        };
                        timeout = mkOption {
                          type = types.str;
                          default = defaults.convert.tesseract.command.timeout;
                          description = "The timeout when executing the command";
                        };
                      };
                    });
                    default = defaults.convert.tesseract.command;
                    description = "The system command";
                  };
                };
              });
              default = defaults.convert.tesseract;
              description = ''
                To convert image files to PDF files, tesseract is used. This
                also extracts the text in one go.
              '';
            };
            unoconv = mkOption {
              type = types.submodule({
                options = {
                  working-dir = mkOption {
                    type = types.str;
                    default = defaults.convert.unoconv.working-dir;
                    description = "Directory where the conversion processes can put their temp files";
                  };
                  command = mkOption {
                    type = types.submodule({
                      options = {
                        program = mkOption {
                          type = types.str;
                          default = defaults.convert.unoconv.command.program;
                          description = "The path to the executable.";
                        };
                        args = mkOption {
                          type = types.listOf types.str;
                          default = defaults.convert.unoconv.command.args;
                          description = "The arguments to the program";
                        };
                        timeout = mkOption {
                          type = types.str;
                          default = defaults.convert.unoconv.command.timeout;
                          description = "The timeout when executing the command";
                        };
                      };
                    });
                    default = defaults.convert.unoconv.command;
                    description = "The system command";
                  };
                };
              });
              default = defaults.convert.unoconv;
              description = ''
                To convert "office" files to PDF files, the external tool
                unoconv is used. Unoconv uses libreoffice/openoffice for
                converting. So it supports all formats that are possible to read
                with libreoffice/openoffic.

                Note: to greatly improve performance, it is recommended to start
                a libreoffice listener by running `unoconv -l` in a separate
                process.
              '';
            };
          };
        });
        default = defaults.convert;
        description = ''
          Configuration for converting files into PDFs.

          Most of it is delegated to external tools, which can be configured
          below. They must be in the PATH environment or specify the full
          path below via the `program` key.
        '';
      };
    };
  };

  ## implementation
  config = mkIf config.services.docspell-joex.enable {

    users.users."${user}" = mkIf (cfg.runAs == null) {
      name = user;
      isSystemUser = false;
      createHome = true;
      home = "/var/docspell";
      description = "Docspell user";
    };

    # Setting up a unoconv listener to improve conversion performance
    systemd.services.unoconv =
      let
        cmd = "${pkgs.unoconv}/bin/unoconv --listener -v";
      in
        {
          description = "Unoconv Listener";
          after = [ "networking.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Restart = "always";
          };
          script =
            "${pkgs.su}/bin/su -s ${pkgs.bash}/bin/sh ${user} -c \"${cmd}\"";
        };

    systemd.services.docspell-joex =
      let
        cmd = "${pkgs.docspell.joex}/bin/docspell-joex ${configFile}";
      in
        {
          description = "Docspell Joex";
          after = [ "networking.target" ];
          wantedBy = [ "multi-user.target" ];
          path = [ pkgs.gawk ];

          script =
            "${pkgs.su}/bin/su -s ${pkgs.bash}/bin/sh ${user} -c \"${cmd}\"";
        };
  };
}
