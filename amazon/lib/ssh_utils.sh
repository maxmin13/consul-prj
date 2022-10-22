#!/usr/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set +o xtrace

#===============================================================================
#          FILE: ssh_utils.sh
#   DESCRIPTION: The script contains general Bash functions.
#       GLOBALS: None
#        AUTHOR: MaxMin, minardi.massimiliano@libero.it
#
# AWS doesn't grant root access by default to EC2 instances. 
# This is an important security best practise. 
# Users are supposed to open a ssh connection using the secure key/pair to login 
# as ec2-user. 
# Users are supposed to use the sudo command as ec2-user to obtain 
# elevated privileges.
# Enabling direct root access to EC2 systems is a bad security practise which AWS 
# doesn't recommend. It creates vulnerabilities especially for systems which are 
# facing the Internet (see AWS documentation).
#
#===============================================================================

#===============================================================================
# Makes a SCP call to a server to upload a file. 
#
# Globals:
#  None
# Arguments:
# +key_pair_file -- local private key.
# +server_ip     -- server IP address.
# +ssh_port      -- server SSH port.
# +user          -- name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +remote_dir    -- the remote directory where to upload the file.
# +file          -- the file to upload.
# Returns:      
#  None  
#===============================================================================
function scp_upload_file()
{
   if [[ $# -lt 6 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 128
   fi
   
   local exit_code=0
   local -r key_pair_file="${1}"
   local -r server_ip="${2}"
   local -r ssh_port="${3}"
   local -r user="${4}"
   local -r remote_dir="${5}"
   local -r file="${6}"
   local file_name=''
   
   if [[ ! -f "${file}" ]]
   then
      echo "WARN: ${file} not found."
      return 0
   fi

   scp -q \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i "${key_pair_file}" \
       -P "${ssh_port}" \
       "${file}" \
       "${user}@${server_ip}:${remote_dir}"
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: uploading file.'
      return "${exit_code}"
   fi
       
   file_name="$(echo "${file}" | awk -F "/" '{print $NF}')"
   
   echo "${file_name} uploaded."       
 
   return "${exit_code}"
}

#===============================================================================
# Uploads a group of files to a server with SCP. 
#
# Globals:
#  None
# Arguments:
# +key_pair_file -- local private key.
# +server_ip     -- server IP address.
# +ssh_port      -- server SSH port.
# +user          -- name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +remote_dir    -- the remote directory where to upload the file.
# +files         -- a list of files to upload.
# Returns:      
#  None  
#===============================================================================
function scp_upload_files()
{
   if [[ $# -lt 6 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 128
   fi

   local exit_code=0
   local -r key_pair_file="${1}"
   local -r server_ip="${2}"
   local -r ssh_port="${3}"
   local -r user="${4}"
   local -r remote_dir="${5}"
   local -r files=("${@:6:$#-5}")
   local file=''

   for file in "${files[@]}"
   do
      scp_upload_file "${key_pair_file}" \
                      "${server_ip}" \
                      "${ssh_port}" \
                      "${user}" \
                      "${remote_dir}" \
                      "${file}"         
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: uploading files.'
         return "${exit_code}"
      fi                 
   done
 
   return "${exit_code}"
}

#===============================================================================
# Makes a SCP call to a server to download a file. 
#
# Globals:
#  None
# Arguments:
# +key_pair_file -- local private key.
# +server_ip     -- server IP address.
# +ssh_port      -- server SSH port.
# +user          -- name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +remote_dir    -- the remote directory where the file is.
# +local_dir     -- the local directory where to download the file.
# +file          -- the file to download.
# Returns:      
#  None  
#===============================================================================
function scp_download_file()
{
   if [[ $# -lt 7 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 128
   fi
   
   local exit_code=0
   local -r key_pair_file="${1}"
   local -r server_ip="${2}"
   local -r ssh_port="${3}"
   local -r user="${4}"
   local -r remote_dir="${5}"
   local -r local_dir="${6}"
   local -r file="${7}"
   
   scp -q \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -i "${key_pair_file}" \
       -P "${ssh_port}" \
       "${user}@${server_ip}:${remote_dir}/${file}" \
       "${local_dir}"
       
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: downloading file.'
      return "${exit_code}"
   fi       
 
   return "${exit_code}"
}

#===============================================================================
# Downloads a group of files from a server using SCP. 
#
# Globals:
#  None
# Arguments:
# +key_pair_file -- local private key.
# +server_ip     -- server IP address.
# +ssh_port      -- server SSH port.
# +user          -- name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +remote_dir    -- the remote directory where the file is.
# +local_dir     -- the local directory where to download the file.
# +files         -- the files to download.
# Returns:      
#  None  
#===============================================================================
function scp_download_files()
{
   if [[ $# -lt 7 ]]
   then
      echo 'ERROR: missing mandatory arguments'
      return 128
   fi

   local exit_code=0
   local -r key_pair_file="${1}"
   local -r server_ip="${2}"
   local -r ssh_port="${3}"
   local -r user="${4}"
   local -r remote_dir="${5}"
   local -r local_dir="${6}"
   local -r files=("${@:7:$#-6}")
   local file=''

   for file in "${files[@]}"
   do
      scp_download_file "${key_pair_file}" \
          "${server_ip}" \
          "${ssh_port}" \
          "${user}" \
          "${remote_dir}" \
          "${local_dir}" \
          "${file}"
          
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: downloading files.'
         return "${exit_code}"
      fi                    
   done
 
   return 0
}

#===============================================================================
# Runs a command on a server as non priviledged user using SSH.
# The function returns the remote command's return code.
#
# Globals:
#  None
# Arguments:
# +cmd           -- the command to execute on the server.
# +key_pair_file -- local private key.
# +server_ip     -- server IP address.
# +ssh_port      -- server SSH port.
# +user          -- name of the remote user that holds the access public-key. 
# Returns:      
#  None  
#===============================================================================
function ssh_run_remote_command() 
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 128
   fi

   local exit_code=0
   local -r cmd="${1}"
   local -r key_pair_file="${2}"
   local -r server_ip="${3}"
   local -r ssh_port="${4}"
   local -r user="${5}"
         
   ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 \
          -o BatchMode=yes -i "${key_pair_file}" -p "${ssh_port}" -t "${user}"@"${server_ip}" "${cmd}"
   exit_code=$?

   return "${exit_code}"   
}

#===============================================================================
# Runs a command on a server as a root using SSH.
# The program 'expect' has to be installed in the local system.
# The function returns the remote command's return code.
#
# AWS doesn't grant root access by default to EC2 instances. 
# This is an important security best practise. 
# Users are supposed to open a ssh connection using the secure key/pair to login 
# as ec2-user. 
# Users are supposed to use the sudo command as ec2-user to obtain 
# elevated privileges.
# Enabling direct root access to EC2 systems is a bad security practise which AWS 
# doesn't recommend. It creates vulnerabilities especially for systems which are 
# facing the Internet (see AWS documentation).
#
# Globals:
#  None
# Arguments:
# +cmd           -- the command to execute on the server.
# +key_pair_file -- local private key.
# +server_ip     -- server IP address.
# +ssh_port      -- server SSH port.
# +user          -- name of the remote user that holds the access public-key
#                   (ec2-user). 
# +password      -- the remote user's sudo pwd.
# Returns:      
#  None  
#===============================================================================
function ssh_run_remote_command_as_root()
{
   if [[ $# -lt 5 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 128
   fi

   local cmd="${1}"  
   local exit_code=0
   local -r key_pair_file="${2}"
   local -r server_ip="${3}"
   local -r ssh_port="${4}"
   local -r user="${5}"
   local password='-'
   
   if [[ "$#" -eq 6 ]]
   then
      password="${6}"
   fi  
  
   if [[ "${password}" == '-' ]]
   then 
      ## sudo without password.
      ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 \
             -o BatchMode=yes -i "${key_pair_file}" -p "${ssh_port}" -t "${user}"@"${server_ip}" "sudo bash -c ${cmd}" 
          
      exit_code=$?   
   else 
      ## sudo with password.
      ## Create a temporary automated script in temp directory that handles the password without
      ## prompting for it.
      local expect_script="${TMP_DIR}"/ssh_run_remote_command.exp
      
      if [[ -f "${expect_script}" ]]
      then
         rm "${expect_script}"
      fi
      
      {  
         printf '%s\n' "#!/usr/bin/expect -f" 
         printf '%s\n' "set timeout -1" 
         printf '%s\n' "log_user 0"
         printf '%s\n' "spawn -noecho ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=60 -o BatchMode=yes -i ${key_pair_file} -p ${ssh_port} -t ${user}@${server_ip} sudo bash -c '${cmd}'"  
         printf '%s\n' "match_max 100000"
         printf '%s\n' "expect -exact \"\: \""
         printf '%s\n' "send -- \"${password}\r\""
         printf '%s\n' "expect eof"
         printf '%s\n' "puts \"\$expect_out(buffer)\""
         printf '%s\n' "lassign [wait] pid spawnid os_error_flag value"
         printf '%s\n' "exit \${value}"    
      } >> "${expect_script}"     
   
      chmod +x "${expect_script}"
      "${expect_script}" 
      exit_code=$?
      rm -f "${expect_script}"     
   fi 

   return "${exit_code}"   
}

#===============================================================================
# Waits until SSH is available on the remote server, then returns. 
#
# Globals:
#  None
# Arguments:
# +private_key -- local private key.
# +server_ip   -- server IP address.
# +ssh_port    -- server SSH port.
# +user        -- name of the user to log with into the server, must be the 
#                 one with the corresponding public key.
# Returns:      
#  None  
#===============================================================================
function wait_ssh_started()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 128
   fi

   local -r private_key="${1}"
   local -r server_ip="${2}"
   local -r ssh_port="${3}"
   local -r user="${4}"
   
   echo 'Waiting SSH started ...'

   while ! ssh -q \
               -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -o ConnectTimeout=60 \
               -o BatchMode=yes \
               -i "${private_key}" \
               -p "${ssh_port}" \
                  "${user}@${server_ip}" true; do
      echo -n . 
      sleep 3
   done;
   echo .

   return 0
}

#===============================================================================
# Tryes to connect to each port passed to the method, if the connection is 
# successful returns the number of the port, if no connection succedes, returns
# an empty string. 
#
# Globals:
#  None
# Arguments:
# +key_pair_file -- local private key.
# +server_ip     -- server IP address.
# +user          -- name of the user to log with into the server, must be the 
#                   one with the corresponding public key.
# +ports         -- a list of port to be verified.
# Returns:      
#  the SSH port number, in the global __RESULT variable.  
#===============================================================================
function find_ssh_port()
{
   if [[ $# -lt 4 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 128
   fi
  
   local exit_code=0
   __RESULT=''
   local -r key_pair_file="${1}"
   local -r server_ip="${2}"
   local -r user="${3}"
   local port=''
   local ssh_port=''

   shift
   shift
   shift

   for port in "$@"
   do
      set +e 
      ssh -q \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout='5' \
          -o BatchMode=yes \
          -i "${key_pair_file}" \
          -p "${port}" \
             "${user}@${server_ip}" 'exit 0'; 

      exit_code=$?
      set -e

      if [[ 0 -eq "${exit_code}" ]]
      then
         ssh_port="${port}"
         break
      fi
   done
   
   __RESULT="${ssh_port}"

   return "${exit_code}" 
}

#===============================================================================
# Creates a RSA key-pair, saves the private-key to the 'pkey_nm' file and the
# public key to the file 'pkey_nm.pub'. 
# The key is not protected by a passphrase.
#
# Globals:
#  None
# Arguments:
# +pkey_nm     -- the name of the file to wich is saved the private key.
# +keypair_dir -- the directory where the keys are saved. 
# +email_add   -- email address.
# Returns:      
#  none.  
#===============================================================================
function create_keypair()
{
   if [[ $# -lt 3 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 128
   fi

   local exit_code=0
   local -r pkey_nm="${1}"
   local -r keypair_dir="${2}"
   local -r email_add="${3}"
   local pkey_file="${keypair_dir}"/"${pkey_nm}"

   if [[ ! -d "${keypair_dir}" ]]
   then
      echo 'ERROR: directory does not exist.'
      return 1
   fi
               
   if [[ -f "${pkey_file}" ]]
   then
      echo 'ERROR: private key already exists.'
      return 1
   fi
   
   ssh-keygen -N '' -q -t rsa -b 4096 -C "${email_add}" -f "${pkey_file}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: creating the key pair.'
      return "${exit_code}"
   fi
   
   chmod 400 "${pkey_file}"
   
   exit_code=$?
   
   if [[ 0 -ne "${exit_code}" ]]
   then
      echo 'ERROR: securing the private key file.'
   fi

   return "${exit_code}"
}

#===============================================================================
# Deletes the key pair files.
#
# Globals:
#  None
# Arguments:
# +pkey_nm     -- the name of the file to wich is saved the private key. 
# +keypair_dir -- the directory where the keys are saved.

# Returns:      
#  None
#===============================================================================
function delete_keypair()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   local exit_code=0
   local -r pkey_nm="${1}"
   local -r keypair_dir="${2}"
   local pkey_file="${keypair_dir}"/"${pkey_nm}"
   
   if [[ ! -d "${keypair_dir}" ]]
   then
      echo 'ERROR: directory does not exist.'
      return 1
   fi
   
   if [[ -f "${pkey_file}" ]]
   then
      # Delete the private key
      rm -f "${pkey_file:?}"
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: deleting private key file.'
         return "${exit_code}"
      fi   
   else
      echo 'WARN: private key not found.'
   fi   

   if [[ -f "${pkey_file}.pub" ]]
   then
      rm -f "${pkey_file:?}.pub"
      exit_code=$?
   
      if [[ 0 -ne "${exit_code}" ]]
      then
         echo 'ERROR: deleting public key file.' 
         return "${exit_code}" 
      fi
   else
      echo 'WARN: public key not found.' 
   fi  
  
   return "${exit_code}"
}

#===============================================================================
# Returns the private key value.
#
# Globals:
#  None
# Arguments:
# +pkey_nm     -- the name of the file to wich is saved the private key. 
# +keypair_dir -- the directory where the keys are saved.
# Returns:      
#  the private key value in the global __RESULT variable.
#===============================================================================
function get_private_key()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r pkey_nm="${1}"
   local -r keypair_dir="${2}"
   local pkey_file="${keypair_dir}"/"${pkey_nm}"
   local private_key=''
   
   if [[ ! -d "${keypair_dir}" ]]
   then
      echo 'ERROR: directory does not exist.'
      return 1
   fi
   
   if [[ -f "${pkey_file}" ]]
   then
      private_key="$(cat "${pkey_file}")"   
   else
      echo 'WARN: private key not found.'
   fi     
   
   __RESULT="${private_key}"
  
   return 0
}

#===============================================================================
# Returns the public key value.
#
# Globals:
#  None
# Arguments:
# +pkey_nm     -- the name of the file to wich is saved the private key. 
# +keypair_dir -- the directory where the keys are saved.
# Returns:      
#  the public key value in the global __RESULT variable. 
#===============================================================================
function get_public_key()
{
   if [[ $# -lt 2 ]]
   then
      echo 'ERROR: missing mandatory arguments.'
      return 128
   fi

   __RESULT=''
   local exit_code=0
   local -r pkey_nm="${1}"
   local -r keypair_dir="${2}"
   local pkey_file="${keypair_dir}"/"${pkey_nm}"
   local public_key=''
   
   if [[ ! -d "${keypair_dir}" ]]
   then
      echo 'ERROR: directory does not exist.'
      return 1
   fi
   
   if [[ -f "${pkey_file}" ]]
   then
      public_key="$(ssh-keygen -y -f "${pkey_file}")"  
   else
      echo 'WARN: private key not found.'
   fi  

   # shellcheck disable=SC2034   
   __RESULT="${public_key}"

   return "${exit_code}"
}

#===============================================================================
# Checks if a private key exists.
#
# Globals:
#  None
# Arguments:
# +pkey_nm     -- the name of the file to wich is saved the private key. 
# +keypair_dir -- the directory where the keys are saved.
# Returns:      
#  true/false in the global __RESULT variable.  
#===============================================================================
function check_keypair_exists()
{
   if [[ $# -lt 2 ]]
   then
      echo 'Error' 'Missing mandatory arguments'
      return 128
   fi

   __RESULT='false'
   local exit_code=0
   local -r pkey_nm="${1}"
   local -r keypair_dir="${2}"

   # shellcheck disable=SC2034      
   if [[ -f "${keypair_dir}"/"${pkey_nm}" ]]
   then
      __RESULT='true'
   else
      __RESULT='false'
   fi

   return "${exit_code}"
}

