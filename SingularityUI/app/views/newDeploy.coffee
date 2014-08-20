FormBaseView = require './formBaseView'

Deploy = require 'models/Deploy'

class NewDeployView extends FormBaseView

    template: require '../templates/newDeploy'

    artifactTemplates:
        embedded: require '../templates/artifactForms/embedded'
        external: require '../templates/artifactForms/external'
        s3:       require '../templates/artifactForms/s3'

    events: ->
        _.extend super,
            'click #executor-type button':       'changeExecutor'
            'click #artifact-button-row button': 'addArtifact'
            'click .remove-button':              'removeArtifact'

    changeExecutor: (event) ->
        event.preventDefault()

        $target = $ event.currentTarget
        @$('.expandable').addClass 'hide'
        $target.parents('.btn-group').find('.active').removeClass 'active'

        executorType = $target.data 'executor'

        @$("\##{ executorType }-expandable").removeClass 'hide'
        $target.addClass 'active'

    addArtifact: (event) ->
        event.preventDefault()
        type = $(event.currentTarget).data 'artifact-type'

        $container = @$ '#custom-artifacts'

        $container.append @artifactTemplates[type]
            timestamp: +moment()

    removeArtifact: (event) ->
        event.preventDefault()
        $(event.currentTarget).parent().remove()

    submit: ->
        event.preventDefault()
        return if @$('button[type="submit"]').attr 'disabled'
        @$('.alert').remove()

        deployObject = {}

        deployObject.requestId = @model.id
        deployObject.id        = @$('#id').val()

        deployObject.resources =
            cpus:     parseInt(@valOrNothing '#cpus') or 1
            memoryMb: parseInt(@valOrNothing '#memory-mb') or 128
            numPorts: parseInt(@valOrNothing '#num-ports') or 3

        deployObject.serviceBasePath = @valOrNothing '#service-base-path'

        deployObject.healthcheckUri                        = @valOrNothing '#healthcheck-uri'
        deployObject.healthcheckIntervalSeconds            = @valOrNothing '#healthcheck-interval'
        deployObject.healthcheckTimeoutSeconds             = @valOrNothing '#healthcheck-timeout'
        deployObject.skipHealthchecksOnDeploy              = @valOrNothing '#skip-healthcheck'
        deployObject.deployHealthTimeoutSeconds            = @valOrNothing '#deploy-healthcheck-timeout'
        deployObject.considerHealthyAfterRunningForSeconds = @valOrNothing '#consider-healthy-after'

        deployObject.loadBalancerGroups  = @multiList '.lb-group'
        deployObject.loadBalancerOptions = @multiMap '.lb-option'

        deployObject.env = @multiMap '.env'

        command = @$('#command').val()
        executor = @$('#executor-type .active').data 'executor'

        if executor is 'default'
            deployObject.uris    = @multiList '.artifact-uri'
            deployObject.command = command
        else
            deployObject.customExecutorCmd = @valOrNothing '#custom-executor-command'
            deployObject.executorData = {}
            deployObject.executorData.cmd = command

            parseIntList = (list) ->
                return undefined if not list
                _.map list, (string) -> parseInt string

            deployObject.executorData.successfulExitCodes = parseIntList @multiList '.successful-exit-code'
            deployObject.executorData.runningSentinel     = @valOrNothing '#running-sentinel'
            deployObject.executorData.user                = @valOrNothing '#user'
            deployObject.executorData.extraCmdLineArgs    = @multiList '.extra-arg'
            deployObject.executorData.loggingTag          = @valOrNothing '#logging-tag'
            deployObject.executorData.loggingExtraFields  = @multiMap '.extra-field'
            deployObject.executorData.sigKillProcessesAfterMillis = parseInt(@valOrNothing '#kill-after-millis') or undefined

            $artifacts = $('.artifact')
            if $artifacts.length
                for $artifact in $artifacts
                    $artifact = $ $artifact

                    type = $artifact.data 'type'
                    if type is 'embedded'
                        deployObject.executorData.embeddedArtifacts = [] unless deployObject.executorData.embeddedArtifacts
                        deployObject.executorData.embeddedArtifacts.push
                            name:     @valOrNothing '.name', $artifact
                            filename: @valOrNothing '.filename', $artifact
                            md5sum:   @valOrNothing '.md5', $artifact
                            content:  @valOrNothing '.content', $artifact
                    else if type is 'external'
                        deployObject.executorData.externalArtifacts = [] unless deployObject.executorData.externalArtifacts
                        deployObject.executorData.externalArtifacts.push
                            name:     @valOrNothing '.name', $artifact
                            filename: @valOrNothing '.filename', $artifact
                            md5sum:   @valOrNothing '.md5', $artifact
                            url:      @valOrNothing '.url', $artifact
                            filesize: parseInt(@valOrNothing '.file-size', $artifact) or undefined
                    else if type is 's3'
                        deployObject.executorData.s3Artifacts = [] unless deployObject.executorData.s3Artifacts
                        deployObject.executorData.s3Artifacts.push
                            name:        @valOrNothing '.name', $artifact
                            filename:    @valOrNothing '.filename', $artifact
                            md5sum:      @valOrNothing '.md5', $artifact
                            s3Bucket:    @valOrNothing '.bucket', $artifact
                            s3ObjectKey: @valOrNothing '.object-key', $artifact
                            filesize:    parseInt(@valOrNothing '.file-size', $artifact) or undefined

        deployModel = new Deploy deployObject, requestId: @model.id
        apiRequest = deployModel.save()

        @lockdown = true
        @$('button[type="submit"]').attr 'disabled', 'disabled'

        apiRequest.error (response) =>
            @postSave()

            app.caughtError()
            @alert "There was a problem: #{ response.responseText }", false
        
        apiRequest.done =>
            @postSave()

            @alert "Deploy successful!"

module.exports = NewDeployView
